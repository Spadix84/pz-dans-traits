# Field guide review, 2026-10-08

**Status (2026-10-08, later):** sections 1 to 3 applied to the guide, README, docs/age.md, the translations and the comments, plus refactor items 1 (skeleton), 4 (age multipliers moved to a table), 5 (Type 1 card points at the dosing table) and 6 (footer). Not done: the Angry moodle descriptions (a translation file cannot follow a sandbox option), the Bounces Back strings (still used: the trait stays defined so old saves can fold it into Thick Skull), refactor items 2 and 3 for the guide, and all of "Code noticed in passing". The three MS bottles still spawn full; only the comment was changed.

Every claim in `docs/field-guide.html` checked against the Lua, the script file, the sandbox options and the translations on branch `age-v2` at dc23bc4 plus the working tree. Points, exclusions, sandbox names and defaults, the six hero counts, the item list and the moodle list all match. What follows is everything that does not, then what the guide leaves out, then the places where the code's own text has drifted, then refactoring.

## 1. Wrong: the guide contradicts the code

Ordered by how much a player would be misled.

1. **Diabetes Type 1 card: "falls with insulin, exercise, alcohol and time".** Type 1 sugar rises with time: `DIA_T1_DRIFT` is 0.17 mg/dL a minute, about 10 an hour (`DanTraits_Diabetes.lua:50,475`). It falls with sleep and, above 180, through the kidneys. The guide's own dosing table says "creeps up about 10 an hour", so the card contradicts the table two screens below it.
2. **Type 1 card and the Insulin row: "the only way down".** Exercise (30 an hour), drink (20 an hour), sleep and the kidneys all lower it (`Diabetes.lua:484-488`). Insulin is the only *treatment* that lowers it. Say that.
3. **Type 1 card: "Starts with a pen".** Three pens of 40 doses, plus the meter and strips (`Diabetes.lua:579-595`). Meter and strips come even with Starting Medication off.
4. **Vitality card: "Fit and Thriving: ... a kilo of carry weight, 1.5x Fitness and Strength experience".** Both need Thriving: the kilo at effect 0.5 (`DanTraits_Vitality.lua:95,379`), the XP at tier 4 (`:114,449`). Fit gets neither. "Run Down and Sluggish: the reverse" is likewise only true of endurance, mood and cold; the kilo is lost only at Run Down, and health is never drained.
5. **In Their 20s card "sleeps through more", 40s card "more night wakes".** The wakes multiplier only scales the wake count fed to the sleep score (`DanTraits_Age.lua:319`, `Vitality.lua:310`). The character wakes exactly as often. The Age table's row ("Night wakes counted in the sleep score") says it right; the two cards overstate it.
6. **Asthma card: "endurance and health drain to a 20% floor".** The health floor is 15 (`DanTraits_Asthma.lua:47`) and endurance has no floor at all: it drains 0.15 a minute to empty (`:45,229`). The file's own header comment says 20%, which is where the guide got it.
7. **Wound infection card: "At 5, fever, and only antibiotics work".** At level 5 the infection goes systemic and topical treatment stops working (`DanTraits_Infection.lua:67,250,336`). The Fever stage shows only when the whole-body score reaches 0.2, which grows 0.1 a day from there (`:68,71,337,371`), so fever follows hours to a day or two later.
8. **Wound care card: "Splinting likewise".** Splints roll a different table: 50% bad at level 0, 6% less a level, floor 2% (`DanTraits_WoundCare.lua:62,176-178`), against stitching's 45% / 5% / 3%. "Set badly, the bone heals at half speed" is right.
9. **Blood card: clotting powder "barely helps with glass or a bullet still in".** It cuts the bleed to x0.6 (`DanTraits_Clotting.lua:31,54`). "Barely" undersells a 40% cut. The Hemophilia card's "only halves" is right.
10. **Medication note and Items note: "the mod's bottles spawn partly used".** Only Anticonvulsants, Metformin, Iron Pills, Diazepam, Nicotine Gum, the Inhaler and Sumatriptan do (`DanTraits_Meds.lua:506-510`). Prednisone, Baclofen and Amantadine spawn full.
11. **Moodles section: "Three have a good side".** Four: Chest Pain, Seizure, Sunburn and Vitality (Fit / Thriving). Antidepressants is good-side only, so five moodles can show green.
12. **Arthritis card: "prednisone cuts it to a third" and "land at a third of the damage".** Both constants are 0.35 (`DanTraits_Arthritis.lua:44,55`). "About a third" would do; the Grit card already says "a third ... 35%".
13. **Quick Study card: "on top of the band's x1.2".** The band factor and the trait factor are separate AddXP handlers that each add their own top-up to the original gain, and the nested event is dropped (`DanTraits_Age.lua:377-422`, `DanTraits_AgeTraits.lua:126-152`). They add: 20s + Quick Study under level 3 is x1.6, not x1.68; 50s + Old Hand on a trade skill x1.4; 50s + Set in Their Ways x0.75. "On top of" is defensible in the guide; `docs/age.md:100` says "multiply", which is wrong. No test covers the combination (`tests/test_agetraits.lua:109-113` runs Quick Study alone).
14. **Sandbox row Starting Medication: "Off: find your own".** Off, a character still starts fully built up on the drug and only the bottle is withheld (`Heart.lua:232-233`, `Epilepsy.lua:209-210`, `MS.lua:456-457`, `Diabetes.lua:597`). `Sandbox.json:38` says so ("Daily pills taken that morning still wear off over a few days"); the guide should too.

## 2. Omitted: in the code, not in the guide

Things a player would want on the card. Grouped by card.

- **Multiple Sclerosis.** No starting-kit line, though every other medicated card has one: starts on baclofen and amantadine, built up, with a bottle of each (`DanTraits_MS.lua:130-131,449-461`). A fever (up to x3), stress (up to x2) and spoon debt all bring flares sooner (`:99-100,259-268`). "12 a day" is the sandbox option, as the Asthma card says of Inhaler Loot.
- **Asthma.** Starts with one inhaler (`:293-301`). A gas mask or respirator blocks cold and corpses entirely and cuts exertion build to a fifth (`:59,149-150`). Sprinting builds irritation on its own at any endurance (`:35,170-174`). Tier 2 already coughs quietly. Asleep it clears twice as fast; during an attack it barely eases on its own (0.001 a minute, `:28,189`), so "eases over four hours at rest" is only true once the attack has ended.
- **Migraines.** Starts with a sumatriptan pack down to its last two tablets (`:143,529-535`). No attack within 24 hours of the last (`:88,399`). Nicotine withdrawal, a concussion and sleeping in a lit room are triggers too (`:67-68,80`). The five weak personal triggers count half, and a strong one is only "worked out" after it has caused two attacks (`:85-86,373`).
- **Diabetes Type 2.** Starts with a meter and strips too (`Diabetes.lua:587-588`); regular exercise cuts resistance by up to 0.25 (`:57,132`).
- **Diabetes, both.** The moodle and symptom messages are hidden while tipsy or drunker (`:402-405,427-431`). Health drains to a 15% floor until 24 hours have been spent over 350, then the floor is gone and it can kill (`:90-91,554`). An inhaler puff raises sugar by 15 (`:64,177-181`).
- **Heart Condition.** A stimulant overdose (too many puffs or caffeine pills) doubles the chest-pain chance (`Heart.lua:46,95`); the 20s cut it x0.8 (`Age.lua:77`), which appears nowhere in the guide.
- **In Their 40s.** Vanilla Handy gets +1 Carpentry at spawn (`Age.lua:82,204-206`). Not mentioned anywhere.
- **In Their 50s.** The 40s card lists what bites harder; the 50s card lists nothing: Brittle x1.5, Heart Condition x1.5, Arthritis x1.6, Type 2 +0.2, Handy +1 Carpentry, Slow Learner gives one fewer (`Age.lua:85-87,99`).
- **Smoker.** Withdrawal's symptoms (irritability floor 0.6 on Angry, hunger, lighter sleep) and 90 days of cue cravings when drunk or stressed after quitting (`Smoker.lua:77-83,97,489-505`). The in-game description mentions the symptoms; the guide does not.
- **Alcoholic.** After the sober month, the first drink is a 50% roll to relapse (`Dependent.lua:34,201-206`). The Smoker card states its equivalent.
- **Thick Skull.** A save with Bounces Back gets Thick Skull (`DanTraits.lua:162`), the note the Iron Gut card carries.
- **A Really Bad Day.** The opening also soaks you through (`BadDay.lua:87-94`); the in-game text says so.
- **Hemophilia.** With Blood Loss off every open bleed costs 0.35 health a minute on top of vanilla and will kill (`Hemophilia.lua:22-23,105-110`).
- **Fear of Blood.** Clotting powder, a poultice or cleaning a burn on a bleeding wound are 10% faints too (`Hemophobia.lua:32-37`).
- **Anaemic.** Iron starts at 0.6 with the deficit from 0.4, so symptoms begin about a day in with nothing eaten (`Anemia.lua:21-23`).
- **Gluten.** The flare scales with carbs: a slice is a two-thirds flare that clears in under seven hours (`Gluten.lua:20`).
- **Sleep and light.** A concussion (up to x2), a fever (x1.5, night x0.7), nicotine or alcohol withdrawal and tinnitus also make light wake you; a sunburnt or hungover night scores worse.
- **Blood.** Endurance recovery is cut 25/50/80/90% by stage and capped in shock (`Blood.lua:73-75,243-249`).
- **Wound infection.** Disinfectant or garlic clears a contaminated wound outright and pushes a local infection back 3 a day under level 5 (`Infection.lua:64,224-227`); a course stopped early is a 50% roll to come back inside 24 hours later (`:82-84,351-364`); sepsis brings delirium.
- **Wound care.** Fresh stitches tear 2% a swing, 5% a minute sprinting until the stitch time passes 40 (`WoundCare.lua:54-59`); walking on an unsplinted break adds fracture time (`:71,299-302`).
- **Concussion.** A moderate knock is a 25% chance of a 1 to 3 minute blackout; a helmet cuts the chance x0.4 and the severity x0.6; a second knock stacks (`Concussion.lua:66-74`).
- **Medication table.** Baclofen and Amantadine are every 12 hours like Anticonvulsants (`Meds.lua:113,121`). The inhaler adds 10 panic a puff (`Asthma.lua:56`). The inhaler's and caffeine pills' overdose is stress and heart strain (`Meds.lua:135,169`), not literally "the shakes".
- **Set in Their Ways.** Fitness and Strength are exempt (`AgeTraits.lua:135`); `docs/age.md:170` says so, the guide and `UI.json:158` do not.
- **Night Shift.** By day, bright light's rest cost is also x0.25, not only the wake chance (`Positives.lua:61,121-124`).

## 3. Drift in the code's own text (not the guide's fault)

- `docs/age.md:100`: "The learning factors multiply with each other and with Quick Study, Old Hand and Set in Their Ways". They add across the two handlers (item 13 above). `docs/age.md:258` lists `DanTraits_AgeLevels` with four arguments; it takes five.
- `DanTraits_Asthma.lua:11` header: 20% floor; the constant is 15.
- `Translate/EN/Moodles.json:32`: Thriving says Fitness and Strength "train twice as fast"; the code is x1.5.
- `Translate/EN/UI.json:112`: Hemophilia "Only bandages slow it"; stitches stop a deep wound and powder halves a bleed.
- `Translate/EN/UI.json:80`: Gym Regular "starts at half regularity"; 65 in the 20s.
- `Translate/EN/Sandbox.json:38`: Starting Medication tooltip lists Heart, Epilepsy, Diabetes, Asthma and Migraines; MS (baclofen, amantadine) and Arthritis (painkillers) are missing.
- `Translate/EN/Moodles.json:2-4`: the overridden Angry descriptions promise effects even with Anger Has Effects off.
- `server/Items/DanTraits_Distributions.lua:6-8` header: sun block 10 and 20; the table is 8 and 15.
- `DanTraits_Distributions.lua:301` comment says every caddy bottle comes part-used; `Meds.lua` SPAWN_TYPES leaves out the three MS bottles.
- `UI.json:161-162` still carries Bounces Back strings for a retired trait (harmless).

## 4. Refactoring

### The guide itself

1. **Give the file a proper skeleton.** It starts at `<title>` with no doctype, charset or viewport. Opened from disk or GitHub Pages it renders in quirks mode, and the middle dot and ellipsis depend on the browser guessing UTF-8. Three lines fix it.
2. **Stop hand-copying numbers.** The same figures live in `DanTraits.txt`, the Lua constants, the README, `docs/age.md`, `UI.json`, `Moodles.json`, `Sandbox.json` and the guide, and this review found drift in five of those. Two cheap steps: a test in `tests/` that parses the `Cost =` lines and the sandbox defaults and asserts the guide's `.pts` spans and sandbox table match; and generating the four pure-data tables (Age every-day, age pricing, drugs, sandbox) from one Lua table via a small script in `DanTraits/tools/`, next to `make_icons.py`.
3. **Make every trait card the same shape.** Right now "Starts with ..." appears on Arthritis, Heart, Epilepsy, Type 1 and Type 2 but not MS, Asthma or Migraines, and "Not with ..." is likewise ad hoc. A fixed last bullet per card ("Starts with: ... Not with: ... Moodle: ...") makes omissions visible at a glance and lets the test in step 2 check exclusions against `MutuallyExclusiveTraits`.
4. **Move the age multipliers off the band cards.** The 40s card lists Arthritis, Brittle, Heart, Type 2; the 50s card lists none; neither lists Handy. Add rows to the Age table (Brittle chance, chest-pain chance, arthritis cold factor, Type 2 resistance, Handy Carpentry) and let the cards say only "see the table". The band cards then stop drifting from it, as "sleeps through more" already has.
5. **Point the Type 1 card at the dosing table** instead of restating the model in one sentence; that sentence is where the "falls with time" error crept in.
6. **Keep the footer, drop the history.** The footer is a changelog; `CHANGELOG.md` already is one. A single "numbers as of commit X" line is enough.

### Code noticed in passing

Not required by the guide, but each is a place where the guide's numbers are at risk because the code holds them twice.

1. **One starting-kit helper.** The create-player handler (kit flag, hours-survived gate, `StartingMedication` check, `MedStart`, AddItem loop) is copy-pasted in MS, Heart, Arthritis, Diabetes, Asthma, Epilepsy, Migraine and PillCaddy. A `DanTraits_StartKit(player, trait, {items}, {drugs})` helper would also give the guide one table of starting kits to print.
2. **One AddXP handler.** Fold `AgeTraits.lua`'s `xpFactor` into `Age.lua`'s handler so the factors multiply as both the comment and `docs/age.md` claim, and delete the duplicate `inList`. Add a test for 20s + Quick Study.
3. **One age-band table.** `AGE_TRAIT`/`AGE_BANDS` in `Age.lua:103-104` and `AGE_BAND_OF`/`AGE_KEYS` in `Client.lua:268,298` are the same data. Export one. Likewise the ten one-line hook registrations in `Age.lua:317-325` could loop over a `{hook = key}` table so the AGE table is the only place a number lives.
4. **One drop-the-weapon routine.** `Arthritis.lua:191-202` drops the primary hand only; `MS.lua:173-194` drops both. A Util helper removes the divergence.
5. **One habit meter.** Smoker and Dependent each hand-roll meter, day cap, cure clock and relapse roll with their own local `setTrait` and `relapseRoll` although `DanTraits_GrantFoldIn` and `DanTraits_RollPercent` exist. They also count the 24-hour window at different tick rates.
6. **Diabetes keeps two copies of the minute model.** `diaPeakIfDosed` (`Diabetes.lua:270-293`) re-implements the drift, kidney and insulin steps of `updateDiabetesMinute` (`:455-490`). Extract one `stepSugar(state, minute)` and call it from both.
7. **Derived constants written as literals.** `HEMO_BLOOD_BANDAGED = 2.5` only means "a quarter" because `BL_BANDAGED = 0.1`; write it as `0.25 / BL_BANDAGED`. `ART_MED_PREDNISONE` and `SLIP_DAMAGE` are 0.35 with "a third" in the comments. The spoon cap default is in `MS.lua:123`, `Spoons.lua:50` and the sandbox file. The Vitality kilo and XP bonus define "Thriving" two different ways (`Vitality.lua:95` vs `:449`).
8. **Parallel chance tables.** `WC_BADSET` and `WC_POOR` are both `{base, per level, floor}` with twin functions; one `rollChance(table, level)`.
9. **Bottle sizes.** The mod's own items carry hand-typed `UseDelta` decimals (0.0333, 0.1666) while `DanTraits_MedPatchScripts` formats vanilla's with the `%.4f` guard; route the mod's items through the same table and share it with `SPAWN_TYPES`.
10. **Sandbox-off paths.** Dehydration and Vitality register `enduranceRegen` hooks that handle "off" differently (nil data versus an explicit check). A wrapper in `DanTraits_AddHook` that returns nil when the option is off would make every system's off path the same thing the guide's sandbox table promises.
