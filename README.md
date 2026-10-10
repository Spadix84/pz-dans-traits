# Project Zomboid Vitality Project

A Project Zomboid (Build 42) mod (internal id `DanTraits`, kept for save compatibility): realistic, balanced traits that add complications to work around, plus a Vitality system that makes fresh food, exercise and sleep matter for everyone.

## Traits

Costs are trait points: negative traits give you points, positive ones cost them. Every trait is listed in one line here and explained in bullets below.

| Trait | Cost | In one line |
|---|---|---|
| [Multiple Sclerosis](#multiple-sclerosis--15) | -15 | Heat is the enemy, and your energy is a daily budget of spoons. |
| [Arthritis](#arthritis--10) | -10 | Stiff joints, flares in the cold and damp, a grip that slips. |
| [Asthma](#asthma--10) | -10 | Irritated airways that build to an attack zombies can hear. |
| [Diabetes Type 1](#diabetes-type-1--10-and-type-2--5) | -10 | A hidden blood sugar model with an insulin pen and a meter. |
| [Heart Condition](#heart-condition--12) | -12 | Strain builds into chest pain; push through it and your heart gives out. |
| [Hemophilia](#hemophilia--10) | -10 | Bleeds never stop on their own; stitches are what stop them. |
| [Migraines](#migraines--10) | -10 | Hours of pain and nausea from personal triggers. |
| [Brittle](#brittle--8) | -8 | Solid hits can fracture a limb. |
| [Major Depressive Disorder](#major-depressive-disorder--8) | -8 | Episodes that hold mood down for days. |
| [A Really Bad Day](#a-really-bad-day--8) | -8 | Drunk, sick, an infected cut, no clothes, house on fire. |
| [Epilepsy](#epilepsy--6) | -6 | Seizures with an aura; anticonvulsants cut them. |
| [Fear of Blood](#fear-of-blood--6-vanilla-reworked) | -6 | Slower first aid, and fainting at the sight of a wound. |
| [In Their 50s](#age-in-their-20s-6-30s-40s--2-and-50s--6) | -6 | Three levels in the main skill, two in the rest of the trade; a body that recovers, heals and trains slower. |
| [Diabetes Type 2](#diabetes-type-1--10-and-type-2--5) | -5 | The same sugar model with the body's own insulin and metformin. |
| [Alcoholic](#alcoholic--4) | -4 | Withdrawal after a day dry; gained by drinking, lost by a sober month. |
| [Anaemic](#anaemic--4) | -4 | Needs iron; short of it you tire, chill and rebuild blood slowly. |
| [Germaphobe](#germaphobe--4) | -4 | Dirty skin and clothes build stress; clean is a relief. |
| [Gluten Intolerance](#gluten-intolerance--4) | -4 | Wheat brings a gut flare. |
| [Smoker](#smoker--4-vanilla-reworked) | -4 | Cravings by habit, withdrawal, damaged lungs; quit or relapse. |
| [Vegetarian](#vegetarian--4) | -4 | Refuses meat, fish and anything cooked with them. |
| [Caffeine Dependent](#caffeine-dependent--2) | -2 | Half a day without coffee or tea brings a headache. |
| [Hallucinations](#hallucinations--2) | -2 | Phantom zombies, sounds, whispers and panic. |
| [Tinnitus](#tinnitus--2) | -2 | Your own gunfire deafens you for a while. |
| [In Their 40s](#age-in-their-20s-6-30s-40s--2-and-50s--6) | -2 | Two levels in the main skill, one in the rest of the trade; a body a little slower to recover. |
| [Lactose Intolerance](#lactose-intolerance--1) | -1 | Dairy brings a mild gut flare. |
| [Straight Edge](#straight-edge--1) | -1 | Refuses alcohol and tobacco. |
| [Cat's Eyes](#cats-eyes-1-vanilla-re-costed) | 1 | Vanilla night vision, re-costed; light wakes you more easily. |
| [Early Riser](#early-riser-1) | +1 | Starts rested; every night scores a little better. |
| [Gym Regular](#gym-regular-1) | +1 | Every exercise starts with a Fitness Instructor's head start. |
| [Hollow Legs](#hollow-legs-1) | +1 | Drink hits less; hangovers milder and shorter. |
| [Meal Prepper](#meal-prepper-1) | +1 | Starts on a good diet; variety counts over five days. |
| [Night Shift](#night-shift-1) | +1 | Daylight hardly wakes you. |
| [Outdoorsman](#outdoorsman-2-vanilla-reworked) | 2 | Vanilla weather resistance; burns half as fast. |
| [Thick Skull](#thick-skull-2) | +2 | Concussed half as often and less badly; knockouts and faints half as long. |
| [Good Clotter](#good-clotter-3) | +3 | Bleeds run down twice as fast and lose less blood. |
| [Iron Gut](#iron-gut-4-vanilla-reworked) | 4 | Vanilla's lower food illness chance; rotten and burnt food does half the harm. |
| [Keen Cook](#keen-cook-4-vanilla-reworked) | 4 | Vanilla's recipes, +2 Cooking and +1 Butchering, plus +1 Short Blade. |
| [Steady Hands](#steady-hands-5) | +5 | Dexterous folded in; stitches and splints go right more often; quicker with a gun. |
| [Deep Sleeper](#deep-sleeper-6) | +6 | Wakeful folded in; light rarely wakes you. |
| [In Their 20s](#age-in-their-20s-6-30s-40s--2-and-50s--6) | +6 | No bonus profession level; recovers, heals and trains faster. |
| [Fast Recovery](#fast-recovery-8) | +8 | Fast Healer folded in; blood comes back faster. |
| [Grit](#grit-8) | +8 | Feels pain a third less. |
| [Renaissance Faire Geek](#renaissance-faire-geek-10) | +10 | +1 Spear, Long Blade, Axe and Blacksmithing. |
| [Resilient](#resilient-10-vanilla-reworked) | 10 | Vanilla's disease resistance, plus a 25% chance to beat the Knox infection. |

### Negative traits

#### Multiple Sclerosis (-15)

Heat is the enemy, and no medicine helps with it. Your energy is a budget.

- **Heat load.** Follows the warm air (24 to 34 C) and your body temperature (exercise, too many clothes). Builds over about half an hour; fades over twenty minutes once cool, twice as fast wet. A drink straight from a tap, well or river takes some off; bottles do not.
- **Warm:** tire sooner, endurance comes back slower.
- **Hot:** stiff, sore, clumsy hands (the game's stiffness on hands and forearms). Swings can throw the weapon, 5% rising to 15%. Pain rises to about 60.
- **Overheated:** severe pain, and a 5% chance a minute the hands give out and drop what they hold. Not while asleep or in a vehicle.
- **Cooling off** clears it within about half an hour. MS takes back its own stiffness and pain.
- **Flares** about once a month, likelier with fever, stress or hours spent at the wall. Three to six days of the heat hitting half as hard again, stiff legs, weak hands and exhaustion.
- **Spoons.** You wake with a day's energy (12 spoons; sandbox option, 0 turns it off). The night sets the refill: hours, how rested you woke, waking, light, fever. A bad night gives fewer, never under a third. A flare caps it at eight.
- **Spending.** Every minute costs by effort (idle a spoon every two and a half hours, sprinting about three an hour), more in the heat, in a flare, in pain, panicking, hungry or uncomfortable. Reading or writing costs a fifth and counts as rest.
- **Running low.** At half, a warning. At three or fewer, stiff legs and slow stamina. At none, the wall: heavy tiredness, legs like a flare's, stamina at a crawl, a swing that can throw the weapon, and every hour you push on borrowed from tomorrow (up to six) with a likelier flare.
- **Getting some back.** Sitting still, not hungry, not laden, gives half a spoon an hour, up to two a day. A nap gives up to four. A coffee hides the wall for an hour, then it lands. You are told the count each morning.
- **Pills** (new items, on the [medication system](#medication)): prednisone makes a flare pass three times as fast from the first pill (hunger while you take it); baclofen builds up over two days to halve the stiffness (mild drowsiness); amantadine builds up over three days to add two spoons to every morning (dry mouth). Starts on baclofen and amantadine, built up, with a bottle of each.
- **Also:** -1 Fitness and -1 Strength; not with Athletic or Strong. Warms up a tenth faster than anyone else. Discomfort (the Uncomfortable moodle) adds stress and spends spoons half as fast again at full discomfort.
- **Moodles:** MS Heat, MS Flare, Spoons.

#### A Really Bad Day (-8)

A CDDA-style start.

- You begin drunk, sick, with an infected laceration on the left forearm, no clothes, and the house on fire.
- The cut is already infected and won't heal until it is treated: about a day and a half before it spreads into the body. Disinfectant pushes it back; once it has spread, only antibiotics do (see [Wound infection](#wound-infection)).
- Disinfectant and a bandage wait in a container in another house 15 to 40 tiles away. No marker; the trait text only says next door.
- Not with Hemophilia or Straight Edge.
- Not balanced yet; see Status and known issues.

#### Arthritis (-10)

Stiff joints and an unreliable grip.

- Slower to move and swing. A Stiff Joints moodle shows how much the weather is in the joints.
- Flares in the cold and damp (humidity, rain outdoors). The cold is read from the joints' own skin temperature, the game's thermoregulator, which clothing, wind and wet feed: gloves and a coat keep a flare off. Only with no reading does the air decide.
- Relief: painkillers halve the weather's share of a flare while they are in your system (about two hours a pill); prednisone cuts it to about a third (x0.35) while you take it. The stronger counts, they do not stack, and neither touches the everyday stiffness. A new character starts with a bottle of painkillers (Starting Medication).
- A swing can slip: 1% calm, more when panicked, hurt, tired or flaring. A slipped swing lands at a third of the weapon's damage.
- Past half a flare one slip in three throws the weapon to the ground instead (a dosed full flare sits exactly at half, and is safe). The sandbox option Arthritis Drops Weapons turns that off.
- Cannot be taken in the 20s; flares sooner in the 40s.

#### Diabetes Type 1 (-10) and Type 2 (-5)

A hidden blood sugar model. You read it with a meter, not a number on screen.

- **Sugar** rises with the carbohydrates you eat and drink, and for Type 1 about 10 an hour with nothing on board. Insulin, exercise, alcohol, sleep and (above 180) the kidneys bring it down; insulin is the only treatment that does.
- **The moodle** (Blood Sugar) says the sugar is out of range, not which way. The glucose meter and a test strip say which.
- **Low:** shaky, tired, anxious, and a bad low puts you on the floor. Steady Hands stops working; Epilepsy seizures are likelier.
- **High:** thirst, and wound infections are likelier and climb faster. Over 350: nausea, and after two hours up there, health drains (a spike after a meal costs nothing; hours of it do).
- **Type 1:** no insulin of your own. Insulin pens (40 doses each) are the treatment. Starts with three pens, a meter and strips (the meter and strips even with Starting Medication off).
- **Knowing your doses (Type 1):** one dose covers about 12.5 g of carbohydrate. With First Aid 3 a food's tooltip (or a sugary drink's, for the whole bottle or mug) says whether its sugar hits fast or slowly and gives a wide range of doses; First Aid 6 narrows the range, and the meter adds how much insulin is still working; First Aid 9 gives the exact doses for your body, and the meter says what it takes to get back to 110 (more doses, or grams of fast sugar), and a food that would spike you past 350 even with its doses says to eat it half, a third or a quarter at a time. The meter's tooltip keeps its last reading and advice. The magazine **Living With Type 1** (new item: hospital magazine racks, medical offices, pharmacies, bookstore and library medical shelves) teaches the First Aid 9 knowledge at any level.
- **Type 2:** the body's own insulin, limited by weight (and by age: more resistance in the 40s, a little less in the 20s). Metformin builds up over two days. Starts on it with a bottle, a meter and strips.

#### Heart Condition (-12)

A weak heart that is pushed too hard. Strain builds, chest pain follows, and a heart attack if you push through it.

- **Strain** (0 to 1) builds every minute from endurance spent, sprinting and running, how winded you are, panic from half way up, carrying more than you can and cold air; it drains at rest (from full to nothing in about 12 minutes standing still). Age (x0.8 / x1.25 / x1.5), a smoking habit, caffeine, a Run Down body, a stimulant overdose and every heart attack survived (+20% each, for good) make it build faster. Shown on the Chest Pain moodle from 0.4 (Heart Working Hard) and 0.75 (Heart Pounding).
- **Chest pain** at full strain: 15 to 30 minutes of pain, endurance recovery at a third, no running or sprinting (the Restricted Movement moodle on an attempt), swings cost half as much again. Twice as fast to pass at rest. Strain falls back to 0.8, so a second bout needs more pushing, not a fresh start.
- **Pushing on through it** (spending endurance at Endurance moodle 2 or worse, trying to run or sprint, or swinging) risks a heart attack each minute (8%, 4% on beta blockers): down for 5 to 15 minutes, 15 health lost, endurance emptied. A second attack within a day drops health to the floor.
- **The week after**, in three stages (Weak Heart moodle): endurance comes back at x0.5 / x0.65 / x0.8, swings, sprinting and running spend x1.5 / x1.3 / x1.15, melee weapons do x0.5 / x0.65 / x0.8 damage, and pushing on through chest pain is x2 / x1.5 / x1.25 as likely to bring another attack. You are told as each stage passes.
- **Beta blockers** (vanilla's pills, on the [medication system](#medication)), one a day, build up over three days to halve the strain build and the heart attack chance; while built up, endurance comes back a tenth slower (anyone on them). You are told when they wear off. Starts on them built up half way, with one bottle.
- **Nitroglycerin** (new item, 25 tablets, where prescriptions are and in a found Pill Caddy): one under the tongue ends chest pain within a minute and halves the strain, then half an hour of headache. Two within an hour drops your blood pressure: faints. Starts with a bottle.
- Not with Athletic (Fit is allowed).
- Moodles: Chest Pain (strain, pain, pushing; green while beta blockers work) and Weak Heart (the week after). Console: `heart`, `heart strain <0..1>`, `heart angina`, `heart attack`, `heart nitro`.

#### Brittle (-8)

- A solid hit (a weapon or a zombie, 2 damage or more) has a 20% chance to fracture one of six limbs.
- Falls and car crashes are judged the way Concussion judges them: nothing under its floor (a hop
  off a fence, a bump at 11 km/h), rising to 40% in a crash certain to concuss (a wall at 70 km/h
  is 40%, a fence at 50 about 22%, a second-floor drop about 7%).
- Likelier in the 40s.

#### Asthma (-10)

Airway irritation that builds through four tiers to an attack.

- **What irritates:** cold air, corpses nearby, exertion (spending endurance when it is already low), panic, smoke, and a wound infection's fever. A mask halves the environmental share.
- **Tier 1:** a warning. **Tier 2:** endurance recovers at half speed, the odd quiet cough. **Tier 3:** no recovery and coughing. **Tier 4, the attack:** endurance drains to empty and health to a 15% floor, you cough loud enough to pull zombies, and an attack that empties you can black you out.
- At rest, irritation eases over about four hours (twice as fast asleep) once the attack has ended; during one it barely eases on its own. The rescue inhaler (new item) ends it at once. Inhalers turn up half as often again as they used to; the sandbox option Inhaler Loot sets the rate.
- Smoking, and a smoker's lungs, make it worse.
- Moodle: Airway Irritation.

#### Hemophilia (-10)

- Bleeds never run down on their own while unbandaged: the bleeding clock is held where it is. A bandage runs it down as usual, and the clock is remembered under the dressing, so changing a bandage carries on from where the old one got to instead of starting the bleed over. Open wounds bleed again until bandaged, unless a bandage already ran their clock to nothing.
- With [Blood](#blood) on: bleeds lose half as much again, and a bandage only slows one to a quarter. A soaked bandage, or one over a shard, is never worse than anyone else's open wound, so change it. Stitches stop a deep wound; a scratch stops only under a bandage.
- With Blood off: every unbandaged bleed costs extra health instead.
- Not with Good Clotter, Fast Recovery or A Really Bad Day.

#### Major Depressive Disorder (-8)

Episodes that hold mood down for days.

- Pain and stress drag mood; a bad night makes an episode likelier.
- An episode holds a mood floor by its severity, with a refractory window after.
- What lifts it: drink (briefly), cigarettes, comfort food, a piece of nicotine gum (a little), exercise, time outdoors, and a real antidepressant regimen.
- Antidepressants: a pill a day, a 14-day build-up, side effects, and discontinuation if you stop. Vanilla's instant lift is gone for this trait.
- Moodles: Depression, and Antidepressants (green while a pill is covering you, paler until the two weeks are up).

#### Migraines (-10)

Attacks that cost you hours.

- **Triggers:** bad sleep, thirst, stress, hangovers, caffeine withdrawal, fever, heat (hot air or an overheated body), corpses close by, a storm on the way (in the twelve hours before it is forecast to start), and bright daylight.
- **Personal triggers:** of the eight lifestyle ones, each character draws three that count double; the other five count half. You are not told which. Once a strong trigger has brought on two attacks, your character works it out and says so.
- **The attack:** an aura first, then hours of pain and nausea (Queasy untreated). Daylight outdoors adds the most pain and halves the recovery; a lit room adds some and slows it; a dark room speeds it. Sunglasses halve the pain the light adds. Your vision blurs for the attack (Short Sighted's blur, its shorter sight and worse aim with it). Sleep shortens it, less in a lit room. A refractory day follows.
- **Painkillers** barely touch an attack: a third of their usual relief, a tenth off the time.
- **Sumatriptan** (uncommon) is what works. Taken in the aura the attack is half as bad; taken during one it is over within two hours with the pain and nausea halved. Once per attack. The day after you are heavy and a little clumsy (a 3% grip slip a swing; moodle: Heavy-Limbed). Starts with a pack down to its last two tablets.
- Moodles: Migraine, Heavy-Limbed the day after sumatriptan (for anyone who takes it), and Light Too Bright during an attack (too bright, the light hurts, blinding: how much the light is adding; sunglasses take it down).

#### Epilepsy (-6)

- Seizures about one in eight days when rested and well. Tiredness, alcohol withdrawal, a hangover, fever, concussion, stress, dehydration, a diabetic low and bright sun make them likelier.
- An aura five to ten minutes ahead (never under 30 real seconds). Then you drop what you hold and are out for 2 to 5 minutes, which can concuss. Then an hour of headache and low mood.
- Asleep, a seizure wakes you and spoils the night instead.
- Anticonvulsants (new item, on the [medication system](#medication)), one every 12 hours, build up over five days to cut seizures to a tenth. You are told when they wear off. Starts on them, built up, with a bottle.
- Moodle: Seizure (the aura before, the hour after), with a good side while the pills work.

#### Fear of Blood (-6, vanilla reworked)

- Vanilla's panic at your own bleeding and stress when bloody stay.
- Treating a wound takes a quarter longer.
- Stitching (25%), pulling out a bullet (35%) or glass (20%), or dressing a bleeding wound (10%) can make you faint: about eight seconds, woken by anything that wounds you. So can losing blood fast.
- Still cannot perform first aid on others.

#### Anaemic (-4)

- Iron drains over about five days. Fresh meat, fish, greens, eggs and iron pills (new item) top it up.
- Short of iron: endurance recovers slower, you tire sooner and catch cold more easily.
- After blood loss, red cells rebuild at half speed, slower still short of iron, and rebuilding them spends iron.
- Wound infections climb faster.
- Moodle: Low Iron.

#### Gluten Intolerance (-4)

- Wheat (bread, pasta, baked goods, beer and dishes made with them) brings on a flare after a short onset.
- The flare ramps up: cramps, nausea, low mood. It takes about ten hours to clear; a second meal during one adds to it.
- Moodle: Gut Flare.

#### Smoker (-4, vanilla reworked)

- Cravings build at half vanilla's pace for a typical smoker, faster the heavier the habit. Withdrawal brings irritability (the vanilla Angry moodle, which now has [effects of its own](#anger)), hunger and restless sleep.
- A cigarette relieves only the craving it answers. To anyone else it is a buzz that fades as tolerance builds.
- Damaged lungs recover endurance slower and cough, worse on exertion and in the morning.
- Anyone who smokes regularly gains the trait; three weeks without tobacco loses it. After that, drink and stress bring cravings back, and a smoke is a coin flip to relapse.
- Smoking speeds up caffeine clearance, lets a wound infection climb faster and slows a deep wound's healing.
- Rare nicotine gum (new item) eases quitting.
- Moodle: Nicotine Craving. The sandbox option Nicotine Craving Moodle hides it, so the craving has to be read from irritability and stress.

#### Vegetarian (-4)

- Meat, fish, insects and anything cooked with them are refused: the eat action will not start.
- Judged by food type, by name and by a dish's ingredients.

#### Germaphobe (-4)

- Dirty or bloody skin (the four worst parts count, not the average), dirty or bloody clothes, and the blood on the weapon in your hands (a dripping one reads 0.5 on its own) build stress and hold mood down.
- Getting clean is a real relief.
- Wounds are a fifth less likely to take an infection.
- Moodle: Filthy.

#### Alcoholic (-4)

- Withdrawal after a day without a drink: craving, low mood and poor sleep, then pain, nausea and the shakes. Heavy drinkers get hallucinations and seizures, and a seizure can concuss.
- The deeper the habit, the sooner and harder it comes. Feeling tipsy ends the craving at a normal habit.
- Anyone who drinks too often gains the trait. A month without alcohol loses it, and any drink after that is a coin flip to relapse.
- The habit is tolerance too: more drink to feel it, hangovers a little milder.
- Moodle: Alcohol Withdrawal (craving, the shakes, delirium).

#### Caffeine Dependent (-2)

- Half a day without caffeine brings a headache, tiredness and low mood. A week dry breaks the habit.
- Coffee, tea and caffeine pills end a craving. A brewed mug counts by what went into it.
- A can of cola or a bar of chocolate is too little to end one but puts it off: six hours for a can, three for a bar.
- Moodle: Caffeine Withdrawal.

#### Hallucinations (-2)

- Episodes roll every ten minutes: a phantom zombie (a harmless sprinter that fades), sounds, thumps, whispers, breaking glass, footsteps, or a bout of panic with the startle sting.
- Likelier with stress, tiredness and night, and with a sleep debt, a concussion, alcohol withdrawal or a fever.
- A concussed or feverish character gets a whisper, not a panic bout.
- Sounds are audio only: they do not attract real zombies.
- No moodle, on purpose. It would give the episodes away.

#### Tinnitus (-2)

- A burst of your own gunfire (by the gun's loudness: half a dozen pistol shots, three from a shotgun) puts vanilla Hard of Hearing on for half an hour or more and Keen Hearing off while it lasts. More shooting adds time.
- The ringing makes light sleep lighter.
- Not with Hard of Hearing or Deaf.
- Moodle: Tinnitus.

#### Lactose Intolerance (-1)

- Dairy, and milk from a carton, brings a mild flare: cramps, queasiness, low mood, gone in about six hours.
- Moodle: Gut Flare, topping out at the second level.

#### Straight Edge (-1)

- Refuses alcohol (drinks and alcoholic food) and tobacco (cigarettes, cigars, pipes, packs, chewing tobacco), and so their relief. Covers I Don't Need A Lighter's stove, fire and car-lighter smoking too.
- Not with Alcoholic, Smoker, Hollow Legs or A Really Bad Day.

### Positive traits

#### Renaissance Faire Geek (+10)

- +1 Spear, Long Blade, Axe and Blacksmithing.

#### Resilient (10, vanilla reworked)

- Less prone to disease and slower to turn, as vanilla. Re-costed from 4 to 10.
- A 25% chance to beat the Knox infection (sandbox option Resilient: Knox Survival Chance). The roll is hidden: you get sick like anyone else, and if you are lucky the fever breaks partway through and the infection is gone. Every new infection rolls again.

#### Grit (+8)

- Pain is felt a third less: the moodle and everything pain drives (aim, mood, sleep). Painkillers still work as vanilla.

#### Fast Recovery (+8)

- Fast Healer folded in (granted; not with Fast Healer or Slow Healer).
- After a bleed, blood volume and red cells come back half as fast again.
- Not with Hemophilia.

#### Deep Sleeper (+6)

- Wakeful folded in (granted; hidden at character creation).
- Light rarely wakes you and costs half the rest; the dark does more good.

#### Steady Hands (+5)

- Dexterous folded in (granted; not with Dexterous or All Thumbs).
- Splints you set go wrong and stitches you put in come out rough half as often. Your fresh stitches tear half as often.
- Stitching, pulling glass or bullets, and splinting take a quarter less time.
- Reloading and racking run a quarter faster (an ammo strap stacks), and a weapon goes to and from the belt a quarter faster.
- Not while your hands shake (alcohol withdrawal, a diabetic low).

#### Iron Gut (4, vanilla reworked)

- Less chance of food illness, as vanilla. Re-costed from 2 to 4, with the old Iron Stomach folded in:
- Rotten and burnt food does half the harm.
- Food sickness climbs half as fast.
- A character with Iron Stomach from an older save gets Iron Gut in its place.

#### Keen Cook (4, vanilla reworked)

- Vanilla's recipes, +2 Cooking and +1 Butchering, plus +1 Short Blade (knife work). Re-costed from 3 to 4.

#### Good Clotter (+3)

- Bleeds run down on their own twice as fast (not while glass or a bullet is still in).
- With [Blood](#blood) on, a bleed loses a quarter less blood; without it, the shorter bleed costs less health.
- Not with Hemophilia.

#### Thick Skull (+2)

- A knock to the head concusses half as often and a quarter less badly, on top of a helmet.
- Concussions heal half as fast again.
- Faints, knockouts and shock last half as long, and so does the day after a sumatriptan (the old Bounces Back, folded in; any age).

#### Outdoorsman (2, vanilla reworked)

- Less affected by harsh weather, as vanilla.
- Takes twice as long to get sunburnt.

#### Cat's Eyes (1, vanilla re-costed)

- Better vision at night, as vanilla. Re-costed from 3 to 1.
- Light wakes you more easily; see [Sleep and light](#sleep-and-light).

#### Early Riser (+1)

- Starts well rested; every night scores a little better.
- Not with Night Shift.

#### Gym Regular (+1)

- Every exercise starts at regularity 50, a Fitness Instructor's head start (65 in the 20s).
- Vitality's exercise score starts neutral instead of empty.

#### Hollow Legs (+1)

- Every drink goes to your head a fifth less, so it takes more to dull pain too.
- Hangovers are milder (x0.6) and shorter (x0.7).
- Not with Straight Edge.

#### Meal Prepper (+1)

- Starts on a good diet.
- Vitality counts food variety over five days instead of three.

#### Night Shift (+1)

- Between 6 AM and 8 PM light wakes you a quarter as easily and costs a quarter of the rest.
- Not with Early Riser.

### Age: In Their 20s (+6), 30s, 40s (-2) and 50s (-6)

Every character is in their 20s, 30s, 40s or 50s and carries one Age trait. Younger bodies recover and train faster; older characters start with more skill. The 30s are the game as it is. The creation screen asks for the age first: until one of the four is chosen nothing else is offered and Next is greyed. In Their 30s costs nothing, the 20s cost 6 points, the 40s give 2 and the 50s 6. The whole system, with every number, is in [docs/age.md](docs/age.md).

- **Profession:** extra levels in the profession's main skill at the start: 0 / 0 / 2 / 3 (the 30s get none: they are the game as it is). Every skill tied for the top boost gets them. Each other skill the profession boosts gets +1 in the 40s and +2 in the 50s. Fitness and Strength never get any; the Unemployed get Maintenance. The creation screen shows them in blue in the Major Skills list.
- **Every day (20s / 40s / 50s against the 30s):**
  - Endurance recovery x1.25 / x0.92 / x0.85.
  - Fitness and Strength experience x1.5 / x0.9 / x0.8.
  - Scratches, cuts and unstitched deep wounds heal x1.5 / x0.9 / x0.8.
  - Stiffness fades x1.5 / x0.85 / x0.7.
  - Night wakes count x0.8 / x1.15 / x1.3 in the sleep score.
  - Red cells rebuild x1.15 / x0.8 / x0.65; a concussion heals x1.2 / x0.75 / x0.6; hangovers x0.85 / x1.25 / x1.5.
  - **The mind:** any skill under level 3 trains x1.2 / x1 / x0.9; the profession's own skills train x1 / x1.1 / x1.15.
  - **The metabolism:** hunger builds x1.15 / x0.95 / x0.9; caffeine, drink, food sickness and daily or course medication clear x1.2 / x0.9 / x0.8 (a daily pill holds a fifth longer in the 50s, and so does everything bad).
- **In Their 20s:** cannot take Handy or Arthritis; Gym Regular starts at 65; Type 2 resistance a little lower; a Heart Condition acts up less (x0.8).
- **In Their 40s and 50s:** Handy gives +1 Carpentry more; Arthritis flares sooner (x1.3 / x1.6); Brittle bones snap more often (x1.25 / x1.5); a Heart Condition acts up more (x1.25 / x1.5); Type 2 resistance is higher.
- **Age pricing:** a trait can cost more or fewer points in a band, shown beside its cost on the creation screen (red dearer, green cheaper). Strong and Athletic +2 / +4 in the 40s / 50s, Stout +1 / +2, Fit -1 in the 20s then +1 / +2; Fast Learner -1 in the 20s and +1 in the 50s; Slow Learner gives a point fewer in the 20s and the 50s; Hearty Appetite gives a point fewer in the 20s and one more in the 50s. The conditions the 20s band softens give fewer points young: Multiple Sclerosis and Heart Condition 3 fewer, Asthma and Hemophilia 2, Type 2, Anaemic, Smoker and Alcoholic 1.
- **Traits only one age can take:**
  - 20s: **Green (-4)**, every occupation skill starts a level lower; **Quick Study (+4)**, skills under level 5 gain experience x1.4; **Bottomless Pit (-6)**, hunger a third faster again and going hungry drags the mood down.
  - 40s: **Pace Yourself (+2)**, a tenth of the stamina a swing or sprint spends comes back; **Settled (-4)**, sleeps badly off a house bed and the first night in any new one.
  - 40s and 50s: **Reading Glasses (-2)**, reading is slow and needs good light without glasses on; **Bad Back (-4)**, a heavy load builds back pain; **Bad Knees (-3)**, running, sprinting, climbing and stomping build knee pain, walking never rests it, sitting rests it twice as fast and a sofa or armchair three times; **Old Hand (+4)**, every skill the occupation boosts gains experience x1.25; **Delicate Stomach (-2)**, junk food and a drink on an empty stomach bring a queasy stomach.
  - 50s: **Old Injury (-3)**, one limb always a little stiff, worse and sore in the cold and damp; **Set in Their Ways (-2)**, skills outside the occupation gain experience x0.85; **Seen It All (+3)**, panic builds a fifth slower, Fear of Blood faints and filth stress halved; **Cast Iron (+2)**, medication side effects half as often and the overdose line a pill higher; **Old Bones Know Rain (+1)**, tomorrow's storm or freezing night announced the morning before.
- **Green** takes the levels away only; it does not change how fast anything trains.
- **Sandbox:** turn age off, set the default decade, set the profession levels per decade.

## For everyone

These run for every character, trait or not. Most have a switch on the Vitality Project sandbox page.

### Vitality

Diet, exercise and sleep roll into one slow score.

- **Diet:** fresh, varied food lifts it; junk and neglect drag it. Variety counts over three days.
- **Exercise:** training (the fitness regularity the exercise menu builds) or a day of hard activity (running, fighting, chopping, heavy work, read from the body's metabolic rate). Activity alone keeps you at neutral; training takes you higher.
- **Sleep:** the night's score, below.
- **Fit and Thriving:** faster endurance recovery, mood and stress relief, faster healing, cold resistance, resistance to wound infection. Thriving alone adds a kilo of base carry weight and 1.5x Fitness and Strength experience.
- **Run Down and Sluggish:** the reverse, except that health is never drained; Run Down alone loses the kilo.
- The conditions above read it too, and so does how fast the body clears an infection, a concussion, an unstitched wound and a smoker's lungs.
- A bad night sets a same-day Slept Badly moodle. A new character starts neutral and cannot fall below it for the first day.
- Moodle: Vitality.

### Sleep and light

The light on your square while asleep sets how deep the sleep is.

- **Dark:** tiredness drains faster, the night scores better.
- **Lit:** tiredness drains slower, the night scores worse, and anything brighter than reading light can wake you (up to about half the hours fully lit). Close the curtains, turn off the lights.
- Exhaustion, drink and sleeping pills sleep through it.
- Light wakes some people more easily: Restless Sleeper, Night Owl, Cat's Eyes, anyone within six hours of a coffee, and during a depressive episode or a migraine. Restless Sleeper's two halves of a night, up to three hours apart, score as one.
- Desensitized characters have nightmares.
- A bad night makes a depressive episode likelier; sleeping with the light on makes a migraine likelier and stops sleep shortening an attack as much.

### Blood

Bleeding drains blood instead of health.

- **How fast:** by how bad the bleed is (the game's own bleeding clock), where it is (neck three times, head, thigh and groin half as much again, chest and belly a little more, hands and feet less), and the dressing: a bandage slows it to a tenth, a shard or bullet left in bleeds through the bandage, stitches stop it, [clotting powder](#wound-care) cuts it to a quarter.
- **15% lost, Pale:** endurance recovers slower.
- **30%, Light-headed:** no sprinting, anxious.
- **40%, Shock:** endurance capped, health draining, and you can pass out for 5 to 15 game minutes.
- **45%, Bleeding Out:** passing out more often. **Half your blood is death.**
- **Recovery:** volume comes back in about a day if you drink, and makes you thirsty. Red cells take about a week, faster fed, asleep and with good Vitality; while short you tire sooner.
- The wound itself still hurts until it is dressed and stitched, as in vanilla.
- Moodle: Blood Loss. The sandbox option Blood Loss turns it off (vanilla bleeding).

### Wound infection

Replaces vanilla's one-roll infection.

- **Each hour** a wound may take an infection: likelier for a deep wound or bite than a scratch, much more with a shard or bullet left in, open or under a spent bandage, or under dirty or bloody clothes. Far less once disinfected, and not at all while disinfectant or garlic is on it (or under a fresh alcohol bandage).
- Prone to Illness and Resilient count, and so do Diabetes (high sugar), Vitality, iron and smoking.
- **Incubation:** 8 to 16 hours unseen. Cleaning the wound then ends it.
- **Growth:** the wound's infection level (the health panel, the pain) climbs about 2 a day, and the wound stops healing. Disinfectant and garlic still push it back.
- **Level 5, spread:** disinfectant and garlic stop working and only antibiotics do. The fever (temperature, the Sick moodle, tiredness, thirst) follows hours to a day or two later. Past that, sepsis drains health, faster the worse it gets. Untreated it kills in a couple of days.
- **Antibiotics** are the game's own pills, one a dose. Each tops up a level in the blood that halves every six hours; while it is high enough the infection falls back. A dose every eight hours keeps it there; ten doses finish a course (a box holds 12). Stop early once it is gone and it has a coin flip to come back. Vanilla's one-pill cure is gone.
- A fever makes for a bad night, brings on migraines, raises blood sugar and irritates asthma. Sepsis brings delirium.
- Zombie infection is untouched, except for [Resilient](#resilient-10-vanilla-reworked)'s chance to beat it.
- Moodle: Infection. A sandbox option turns it off.

### Wound care

- **Bandages** wear out over about a day, faster wet and faster still as blood soaks through. Spent, a bandage only halves a bleed and invites infection, and you are told to change it.
- **Unstitched deep wounds** heal at about a third of the speed, and hard use of the limb can open them again.
- **Fresh stitches** can tear: swinging a weapon with a stitched arm, sprinting or running on a stitched leg, less on the torso, less under a bandage. They hold better as they heal and are sound once the game's stitch time passes 40. Torn, the wound is open and bleeding again.
- **Stitching is a First Aid roll:** 45% rough at level 0, 5% less a level, never under 3%; a suture needle or needle holder takes it to 0.6 of that, Steady Hands halves it. Rough stitches knit at half speed, tear twice as easily, ache, and let infection in like an open wound until they are sound. A stitcher at level 3 or more can tell. Take them out and stitch again.
- **Splinting is a First Aid roll:** half the time badly set at level 0, 6% less a level, never under 2%. Set badly, the bone heals at half speed and hurts; only a setter at level 3 or more can tell. Take it off and set it again.
- Moving on a broken leg with no splint makes the break worse.
- A sandbox option turns it off.
- **Clotting powder** (new item, 5 uses; medicine cabinets, first aid kits, doctors' and medics' bags, pet shops, salons, army medical): right-click a bleeding part in the health panel with the dressing off. A scratch or cut stops bleeding; a deep wound's bleed is halved and then cut to a quarter for 12 hours (it still needs stitches), and a bandage over it soaks that much slower. It stings, less with First Aid. Barely helps with a shard or bullet still in (x0.6); a hemophiliac's bleed only halves and never stops. The clot breaks if the wound tears or opens again. Fear of Blood can faint at it, like a bandage. Not switched off with wound care.

### What First Aid tells you

The health panel's wound list is written for the examiner's First Aid level: your own, or the doctor's for a patient, read live.

- **0 to 2:** what anyone can see. Scratched, cut, a bad cut, bitten, bleeding, something stuck in it, a dressing, "might be broken", and an infection only once it is red and swollen. No severities.
- **3 to 5:** the game's own detail, plus infected, a dressing wearing thin, a badly set bone and rough stitches.
- **6 to 8:** how far an infection has got and how stitches are holding.
- **9 and 10:** an infection that has not shown yet, and how far a break has healed.
- Wraps whichever list drawing is installed, so it works over mods that replace it (NestedHealthInfo), and leaves the debug view alone.

### Concussion

- **Causes:** a hard landing (from about the second floor up), a car crash (by the speed the car loses: nothing under about 25 km/h lost, so running down a zombie at speed is nothing; a wall at 50 a good chance; certain and severe from 70), being hit by a car, or a weapon hit that takes health off the head. A helmet makes it less likely and less bad.
- **Dazed:** a headache, drowsy.
- **Concussed:** sick to the stomach too, bright daylight makes the headache worse, slower to get your breath back, and running or fighting can bring on a dizzy fall; a quarter of the time it knocks you out briefly.
- **Badly concussed:** knocked out on the spot for 5 to 15 game minutes.
- **Healing:** rest heals it, sleep twice as fast; running and fighting stop it healing. A second knock lands on top of the first.
- **The headache after:** a chance (half, plus half the severity) of a post-concussion headache one to two and a half days later, often after the concussion has cleared. It builds over six hours to a pain worse than the knock's own, holds, and fades over its last twelve hours, lasting a day to two by severity. Sleep gets through it half as fast again; daylight makes it worse; painkillers dull it.
- It brings on migraine attacks and makes light wake you more easily. Shown on the head in the health panel.
- Moodle: Concussion. A sandbox option turns it off.

### Passing out

Shock, a concussion and Fear of Blood can all put you on the floor.

- You fall, end up sitting, the screen goes black, and you can do nothing until you come round, for game minutes but never under eight real seconds. After those eight seconds time runs fast, as it does asleep, and goes back to normal when you come round (a paused game stays paused). You come round sitting on the floor and get up yourself. Zombies can still get to you.
- In a vehicle there is no fall: you slump in the seat, and a driver's engine cuts out so the car rolls to a stop.
- A faint is shallow: anything wounding you jolts you awake. A concussion knockout is not.

### Sunburn

- Outdoors in sunshine (day, no rain, less under cloud, nothing at 5 C and full from 20 C, full from 11 to 3 and gone by 7 morning and evening), every body part no clothing covers builds exposure. About three hours of midday summer sun burns bare skin; "your skin feels hot" comes first.
- A burnt part hurts, on that part, for a day, easing over the last six hours. The game adds the parts up: one burnt hand is a nuisance, a whole body burnt is agony for most of the day.
- It makes for a worse night, and the health panel shows Sunburnt on the part. Shade or indoors lets exposure fade.
- Skin toughens: each burn makes the next take longer, and the tan fades over a month. Outdoorsman skin takes twice as long to burn.
- **Sun block** (new item, as common as toothpaste; 8 coats) keeps the sun off all bare skin for 8 hours a coat. You are told when it wears off.
- Moodle: Sunburn, with a good side while sun block is on. A sandbox option turns it off.

### Dehydration

- Vanilla thirst only costs health at the top end. Hours at Thirsty or worse (twice as fast Parched, three times Dying of Thirst) now build a load: a headache, tiredness and slower endurance recovery.
- It drains in about two hours once you have drunk.
- Moodle: Dehydration. A sandbox option turns it off.

### Anger

The vanilla Angry moodle does nothing in the base game. Here it costs you, from Annoyed up; Irritated is only the warning. A smoker's withdrawal is what raises it (up to Angry at full withdrawal), and anger from another mod counts the same.

- **Rough:** every melee hit has an extra chance to wear the weapon: half as much again at Annoyed, double at Angry, two and a half times at Furious. Anger never takes a weapon's last point. Furious swings cost extra endurance.
- **Loud:** from Angry up the character curses out loud now and then (about once an hour, more often and louder at Furious), and zombies nearby hear it. Never asleep, and never within three minutes of a cough.
- **Can't concentrate:** reading takes longer: x1.15 Annoyed, x1.3 Angry, x1.5 Furious.
- **Sloppy fine work:** splints set badly and stitches come out rough more often (x1.25, x1.5, x2), and installing or removing a vehicle part is 5, 10 or 20 points less likely to succeed and as much more likely to damage the part. The mechanics window shows the angry chance.
- The moodle's descriptions say so. The sandbox option Anger Has Effects turns it off.

### Hangovers

- Drink past a light buzz and a hangover waits for you to sober up, or to wake: at least six hours of headache, low mood, thirst and tiredness, longer and with nausea after a heavy night.
- Two hours properly drunk is a full-strength one, and even a small one is felt (never under two fifths strength).
- Endurance comes back slower while it lasts (up to 40% slower), and bright daylight outdoors makes the headache worse.
- Painkillers only dull it: one taken while hungover works for half as long.
- A drink hides it and stops the clock, and counts toward the next one.
- Alcoholics carry the habit as tolerance: more drink to feel it, withdrawal sooner and harder, hangovers a little milder.
- Moodle: Hangover. A sandbox option turns it off.

### Drink relief

- Vanilla treats any sip of alcohol as a full dose of beta blockers and painkillers, however small. That is undone.
- Relief follows the Drunk moodle instead: pain reduction of 20, 40, 60 or 80 by level, and panic that settles at a quarter, half, three quarters or the full beta-blocker rate.
- Being drunk lifts the mood too: unhappiness, stress and boredom drain while you are awake, faster the drunker you are. Tipsy takes the edge off (3 unhappiness an hour); blind drunk takes 30 an hour, so an evening of it clears even a severe mood. The hangover is the price. A depressive episode keeps its own floor.
- A sandbox option turns it off.

### Medication

One list of drugs that every trait reads (`DanTraits_Meds.lua`).

- **Daily drugs** (beta blockers, anticonvulsants, metformin, baclofen, amantadine) have a level in your system that every pill tops up and a half-life drains, and a build-up: a little after the first pill, fully after a few days of regular doses. A missed dose lets them fade slowly, not all at once.
- **Rescue drugs** (diazepam, sumatriptan, prednisone) work at once while they are in your system.
- **Everything else** that is taken is on the list too (inhaler, nicotine gum, painkillers, sleeping tablets, caffeine pills, the insulin pen's doses): each keeps what it does and gains a level, a side-effect roll and a too-many effect. Four painkillers at once bring strong nausea, too many sleeping tablets a blackout risk, five inhaler puffs or four caffeine pills the shakes (and chest pain twice as likely for Heart Condition).
- **Side effects:** on each day a drug is taken, a small chance (3%, sandbox option Medication Side Effect Chance) of its mild side effect for a few hours. Stomach ones bring on the game's nausea moodle. Some act on anyone the whole time: prednisone's hunger, baclofen's drowsiness, amantadine's dry mouth.
- **Wearing off:** a drug's moodle (beta blockers, anticonvulsants) is paler green while it builds up and full green once it has, and goes out when the drug leaves your system. You are told when a protecting drug lapses.
- **Starting Medication** (sandbox option, on): a character who starts with a condition starts on its drug, built up, with the medication. Off, they find their own.
- **Diazepam** (new item): the panic drop vanilla beta blockers used to give, for about an hour and a half. Beta blockers now only do what Heart Condition needs.
- **Pill Caddy** (new item, uncommon): a belt-worn weekly organiser that holds medication only. Capacity 1 (Organized makes it 2). Found in medicine cabinets, bedside drawers, handbags, on pharmacy shelves and on the odd zombie, and a found one often has a bottle or two in it. A new character with a medical trait has a 1% chance to start with one.
- Daily drug bottles hold 30 pills, most of the mod's bottles spawn partly used (Prednisone, Baclofen and Amantadine full), and part bottles merge like vanilla's. Every tooltip says what the drug treats, how to take it and its side effects. Antidepressants keep Depression's own two-week regimen, with a moodle of their own: paler green while a pill's coverage runs, full green once the two weeks are up, gone when a day is missed.

### Moodles

Every effect that lasts has one. All of them need [Moodle Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3396446795); everything else works without it.

- The older systems feed their own: Airway Irritation, Vitality, Slept Badly, Hangover, Migraine, Blood Loss, Infection, Concussion, Blood Sugar.
- The rest are fed from one place (`DanTraits_Moodles.lua`): Chest Pain, Seizure, Tinnitus, Gut Flare, Filthy, Sunburn, Dehydration, Caffeine Withdrawal, Alcohol Withdrawal, Nicotine Craving, Depression, Low Iron, Stiff Joints, MS Heat, MS Flare, Spoons.
- Three have a good side: beta blockers working, anticonvulsants working, and sun block on. The icon going out is the reminder to take the next one.
- Blood Sugar says the sugar is out of range but not which way; the meter is how you find out. Hallucinations has none; it would give the episodes away.

## Layout

```
DanTraits/42/            the mod as the game sees it (mod.info, poster.png, media/...)
DanTraits/common/        empty; Build 42 expects it beside 42/
  media/lua/shared/      one file per trait + DanTraits.lua (core helpers, eat/pill hooks)
  media/lua/client/      context menus, moodles, telemetry for the dashboard
  media/scripts/         trait and item definitions
DanTraits/tools/         dashboard.py + Dashboard.bat (live readout and command console),
                         make_icons.py (draws the moodle, item and age trait icons)
tests/                   offline tests (fengari); python tests/run_tests.py
workshop/                workshop.txt and preview.png for the Steam Workshop page
deploy.py                copy the mod to ~/Zomboid/mods (or --pull edits back, or --workshop)
```

Mod data is one table per player (`getModData().DanTraits`) with a prefix per system (`alc*`, `nic*`, `inf*`, ...); the dashboard groups it by that prefix. A renamed key is moved by `DanTraits_MigrateModData` in the core.

## Workflow

1. Edit in this repo.
2. `python tests/run_tests.py`
3. `python deploy.py` then restart the game (traits, items and Lua are read at boot). While the Workshop upload folder (`~/Zomboid/Workshop/DanTraits`) exists the game loads that copy instead of `~/Zomboid/mods/DanTraits`, so the deploy mirrors into both and they never differ.
4. `DanTraits/tools/Dashboard.bat` for a live readout at http://127.0.0.1:8642 with buttons to trigger any trait's events. The game side of it (telemetry file and command channel) only runs in debug mode (start the game with `-debug`), and never in multiplayer.

To publish: `python deploy.py --workshop` builds `~/Zomboid/Workshop/DanTraits` (workshop.txt, preview.png and `Contents/mods/DanTraits` without the dev tools), then upload it from the game's main menu, Workshop. After the first upload the game writes the item's `id=` into that workshop.txt; the build keeps it, so later uploads update the same item.

The game's Lua (Kahlua) allows 200 locals and 60 upvalues per function, the file's top level included, so new traits go in their own file (`require "DanTraits"` for the shared helpers). It also lacks `next`, `assert`, `xpcall`, `string.gmatch` and `string.rep`. The offline tests run on standard Lua and would not notice any of that, so `tests/lint_kahlua.py` (run first by `run_tests.py`) checks for it, and checks the translation files too: valid JSON, no duplicate keys, and no bare `%` (the game formats UI strings; write `%%` for a percent sign, `%1` for a placeholder). Calling a Java method an object doesn't have fails quietly inside `pcall` but dumps a stack trace to the log every time, and the tests' stand-ins can't notice, so `tests/check_api.py` (also run by `run_tests.py`) checks the method names called on body parts, body damage, players, stats and weapons against the installed game's jar.

## Status and known issues

Version 1.2.0, Build 42, singleplayer only (multiplayer is untested and not supported). What changed in each update is in [CHANGELOG.md](CHANGELOG.md); the Workshop page carries the short version.

- **A Really Bad Day** is not balanced yet. Its glass shard killed even a character with no other traits, so for now the wound is an infected cut and the trait gives 8 points instead of 12, until a proper balance is found.
- **Invisible character** (seen once, in debug mode, after a heart-attack blackout and some console commands): the model vanished, reloading didn't fix it, and restarting the game did. Nothing in the mod touches visibility; the likeliest cause is debug mode's own invisibility toggle. If you see it, before reloading, run `print(getPlayer():isInvisible())` in the debug console and report the result and what you were doing.
- Other health overhauls (anything that replaces bleeding, infection or the health panel) will likely conflict.
- **Take A Bath And Shower** is supported: a bath or shower washes sun block off (`DanTraits_Bathing.lua`), and in Dan's Vanilla Fixes the hand-wash floors apply to the clothes you bathe in (`DansVanillaFixes_Bathing.lua`); both do nothing when it is not loaded. Its gradual body wash is what Germaphobe reads anyway, a wet body cools Multiple Sclerosis as it should, a hot bath warms an MS character (by design on both sides), and its bath salts keep their effects (a calming salt is the game's beta-blocker effect, a happy one its antidepressant effect, which an MDD character's own regimen overrides).
- **Project A-Life** (NPCs on zombie bodies) is supported: its NPCs and its zombie steering leave a Hallucinations phantom alone (`DanTraits_ALife.lua`, which does nothing when A-Life is not loaded). NPC wounds are ordinary wounds, so blood, infection and wound care apply to them, and an NPC's blow, shot or graze counts as a weapon hit for Concussion and Brittle (the game itself does not report those).
- **Bandits** (and its add-ons) is supported: bandits, hostile or friendly, leave a Hallucinations phantom alone, and a bandit's hit counts as a weapon hit for Concussion (all of its damage on the head for a head hit) and Brittle (`DanTraits_Bandits.lua`, which does nothing when Bandits is not loaded). A bandit's head shot knocks a helmet off before the concussion roll, so the helmet does not help against that one.

## Requests

Ideas from the Reddit thread still under review (sumatriptan, personal migraine triggers, the Arthritis weak swing and the stitching roll from the same thread shipped in 1.1.0):

- **Fructose Intolerance**: a trait on the Gluten and Lactose pattern for fruit and sugary drinks.
- **A sleep mask**: an item that makes a lit room dark for the sleep system.
- **Illnesses without a trait**: a cold, flu or food poisoning that has to be diagnosed from symptoms, not announced.
- **Evolving Traits World compatibility**: ETW hands out and removes Smoker at runtime; the nicotine meter should follow it.

## Bug reports

Open an issue on GitHub with your mod list, what happened, and `~/Zomboid/console.txt` from the session. Balance feedback is just as welcome.

## License

MIT, see [LICENSE](LICENSE).
