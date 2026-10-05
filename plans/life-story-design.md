# Life Story: guided character creation

Design draft, 2026-10-02. Nothing here is built.

## The problem

Vanilla creation is a points market. Every trait has a price and no trait is
connected to any other, so the winning move is to buy cheap negatives you can
ignore and spend the proceeds on strong positives. The character is a
spreadsheet result. Once you know the spreadsheet, every run is the same run.

## The idea

Stop selling traits one at a time. Sell lives.

A negative should arrive because of where it came from, bundled with the
positive that came from the same place. You do not pick Arthritis for 10
points. You pick twenty years on construction sites and get strong arms,
carpentry, and knees that are going. The trade is baked into the fiction, so
it cannot be gamed the way a price list can.

Three things make it hold:

1. **Chapters, not traits.** Each card is a life chapter with a package of
   skills, positives and conditions. Cards are balanced against each other
   (see the rule below) so no card is simply the best card.
2. **Hidden consequences.** Some cards carry a *latent* condition at a stated
   chance. It is rolled at creation and not shown. You find out when it first
   fires. The spreadsheet is incomplete by design.
3. **Personality with teeth.** Chapters nudge four personality axes, and the
   axes change how the character feels and behaves in play. The character is
   someone, not a loadout.

It is a sandbox mode, off by default. Vanilla creation stays available.

## The flow

```
Profession  ->  Age  ->  Chapters  ->  Who you are  ->  Free points  ->  Play
                 |          |              |                 |
           20s/30s/40s/50s one card per   personality       3 points,
             (existing)   deck, decks    summary, one      vanilla list,
                          by age         nudge allowed     locked otherwise
```

- **Profession and age** are the existing screens and the existing Age system.
- **Chapters.** Everyone draws from the *Upbringing* deck. Then one card per
  decade lived: a 20-something plays Upbringing + Twenties (2 cards), a
  30-something adds Thirties (3), a 40-something adds Forties (4), a
  50-something adds Fifties (5; that deck is not written yet). Older means
  more skills and more baggage, which is the trade Age already wants to express.
- **Cards constrain cards.** A card can require, exclude or cheapen later cards.
  Desk Job after Construction Crew is "got out of the trade"; Construction Crew
  after Desk Job is not offered.
- **Who you are** shows the four axes as a short paragraph ("Restless, keeps to
  herself, careful to a fault") and lets the player move one axis one step.
- **Free points.** Three points on the vanilla list for flavour. Not enough to
  min-max with. Traits already granted or excluded by cards are locked.

## Card anatomy

```
Name            Construction Crew            Decks: Twenties, Thirties
Flavour         Ten years of framing houses in the Kentucky heat.
Grants          Stout, +2 Carpentry, Thick Skull
Costs           Tinnitus
Latent          Arthritis 40% (only fires in the 40s)
Personality     Disciplined +1, Reckless +1
Rules           Not after Desk Job. Age 20s: Stout becomes +1 Strength XP boost.
```

Every card has at least one real cost. A card with only upside is a loadout.

### The balance rule

Using the mod's existing trait costs (README table) and 1 point per granted
skill level, every card nets between **-3 and +3**, where a latent condition
counts at its chance times its cost. The deck must never offer a plainly
better card; the differences between cards should be *kind*, not *amount*.
This rule is a unit test (see Testing), not a hope.

Cards are allowed to be fuzzy to compare. That is the point of latents and of
personality costs that have no number on them.

## First deck: 22 cards

Costs in brackets are the current DanTraits/vanilla costs, for the balance
check. Vanilla costs are from memory and need confirming against B42. Numbers
are a first pass to tune in play.

### Upbringing (everyone picks one)

| Card | Grants | Costs | Latent | Personality |
|---|---|---|---|---|
| Farm Kid | Outdoorsman (+2), Iron Stomach (+1), +1 Farming, +1 Animal Care | Slow Reader (-2) | Lactose Intolerance 20% (-1) | Disciplined +1, Loner +1 |
| City Kid | Fast Reader (+2), +1 Sneaking, +1 Electrical | Weak Stomach (-3) | | Social +1, Reckless +1 |
| Sickly Child | Fast Learner (+6), +1 First Aid | Brittle Asthma (-8) | Anaemic 30% (-4) | Cautious +1, Anxious +1 |
| Scout Troop | Former Scout (+1 First Aid, +1 Foraging), Early Riser (+1) | Straight Edge (-1) | Fear of Blood 20% (-6) | Disciplined +1, Cautious +1 |
| Rough Start | Thick Skinned (+6), +1 Short Blunt, +1 Lightfooted | Short Tempered (-2), Slow Reader (-2) | Alcoholic 25% (-2) | Reckless +1, Loner +1 |

### Twenties

| Card | Grants | Costs | Latent | Personality |
|---|---|---|---|---|
| College Years | Fast Reader (+2), +2 in the profession's main skill, Night Owl (+2) | Caffeine Dependent (-2), Hearty Appetite (-4) | Smoker 40% (-4) | Social +1, Impulsive +1 |
| Construction Crew | Stout (+6), +2 Carpentry, Thick Skull (+2) | Tinnitus (-2) | Arthritis 40%, 40s only (-10) | Disciplined +1, Reckless +1 |
| Gym Rat | Fit (+6), Gym Regular (+1), Meal Prepper (+1) | Hearty Appetite (-4) | Brittle 15% (-8) | Disciplined +1, Social +1 |
| Party Years | Hollow Legs (+1), Night Owl (+2), +1 Short Blunt | Alcoholic (-2), Smoker (-4) | Hallucinations 15% (-2) | Social +2, Impulsive +1 |
| Shift Worker | Night Shift (+1), Night Owl (+2), +1 in the profession's main skill | Caffeine Dependent (-2) | Migraines 25% (-10) | Loner +1, Calm +1 |
| Enlisted | Brave (+4), +1 Aiming, +1 Reloading, +1 Fitness | Tinnitus (-2), Short Tempered (-2) | Hallucinations 20% (-2) | Disciplined +1, Calm +1 |
| Diagnosed | Organised (+6), +2 First Aid, Meal Prepper (+1); starts on medication | one of: Diabetes T1 (-10), Epilepsy (-6), Heart Condition (-10), MS (-15, also grants Fast Learner) | | Disciplined +1, Anxious +1 |

### Thirties

| Card | Grants | Costs | Latent | Personality |
|---|---|---|---|---|
| Desk Job | Organised (+6), Fast Reader (+2), +1 Electrical | Out of Shape (-6), Short Sighted (-2), Caffeine Dependent (-2) | | Cautious +1, Disciplined +1 |
| Parenthood | Early Riser (+1), Nutritionist (+4), +1 Cooking, +1 First Aid, +1 Tailoring | Restless Sleeper (-6) | | Calm +1, Cautious +1 |
| On the Road | Speed Demon (+1), Night Owl (+2), +2 Mechanics, +1 Maintenance | Smoker (-4), Caffeine Dependent (-2) | Diabetes T2 30%, 40s only (-5) | Loner +1, Calm +1 |
| Volunteer EMT | Steady Hands (+5), +3 First Aid | Germaphobe (-3) | Major Depressive Disorder 20% (-8) | Social +1, Calm +1 |
| Hard Times | Light Eater (+4), Hollow Legs (+1), +1 Foraging, +1 Tailoring, +1 Mechanics | Major Depressive Disorder (-8) | Alcoholic 40% (-2) | Anxious +1, Loner +1 |
| Community Pillar | +1 Carpentry, +1 Cooking, +1 Farming, Early Riser (+1) | Straight Edge (-1), Pacifist (-4) | | Social +2, Calm +1 |

### Forties

| Card | Grants | Costs | Latent | Personality |
|---|---|---|---|---|
| Management | Organised (+6), Fast Reader (+2), Lucky (+4) | Out of Shape (-6), Short Tempered (-2), Caffeine Dependent (-2) | Heart Condition 25% (-10) | Disciplined +1, Cautious +1 |
| Old Injuries | Thick Skinned (+6), Brave (+4), +1 Short Blunt | Arthritis (-10), Tinnitus (-2) | | Calm +1, Cautious +1 |
| Hobbyist | one of: Renaissance Faire Geek (+10), Hunter, Angler, Herbalist | Conspicuous (-4), Hearty Appetite (-4) | | Social +1, Impulsive +1 |
| Caretaker | +2 First Aid, +1 Cooking, Early Riser (+1), Resilient (+4) | Restless Sleeper (-6) | Major Depressive Disorder 30% (-8) | Calm +1, Anxious +1 |
| Doctor's Orders | Meal Prepper (+1), Organised (+6), +1 First Aid; starts on medication | one of: Diabetes T2 (-5), Heart Condition (-10), Arthritis (-10) | | Disciplined +1, Anxious +1 |

Notes on the deck:

- **Diagnosed / Doctor's Orders** are the one place the player picks a
  condition directly. The compensation is the same package whichever condition
  is chosen, so the choice is about *which* hard life, not whether to have one.
  MS gets Fast Learner on top because -15 is in a class of its own.
- **Age-gated latents** (Arthritis, Type 2) only fire in the 40s. A
  20-something with Construction Crew carries nothing. The same card is a
  different bet at a different age, which is exactly what Age was for.
- **Smoker and Alcoholic** as latents mean the habit is there but not yet a
  trait: the mod's existing "anyone who drinks or smokes enough gains it"
  path, with the threshold lowered for that character.
- Stacking rules: a trait granted twice is granted once (no refund). A card
  whose grant is already held offers a swap from a short list, so Early Riser
  twice is not a dead slot.

## Personality

Four axes, each from -2 to +2, set by cards, with one step of player nudge.
Zero is vanilla behaviour. Effects scale linearly with the step.

| Axis | +2 side | -2 side |
|---|---|---|
| Caution | **Cautious**: panic rises 20% slower, stress from damage 20% lower, Fear of Blood faints 25% rarer; endurance recovers 10% slower (always tense) | **Reckless**: melee damage +10%, sprint endurance cost -10%; panic from being surrounded +30%, concussion 25% likelier on a fall |
| Calm | **Calm**: stress and unhappiness fall 20% faster, migraine stress trigger halved, Hallucinations panic bouts become whispers | **Anxious**: notices sound cues 1 tile further, wakes 20% more easily; stress rises 20% faster, bad nights 25% likelier |
| Social | **Social**: boredom and unhappiness fall 30% faster within 10 tiles of another player or a radio/TV; 20% slower alone | **Loner**: the reverse; also +1 effective Sneaking indoors alone |
| Discipline | **Disciplined**: daily medication build-up 20% faster, Vitality exercise score 15% faster; comfort food relief halved | **Impulsive**: all craving relief (drink, smoke, coffee, food) 25% stronger; cravings return 25% sooner, relapse coin flips 60/40 against |

Rules:

- Effects live in mood, stress, sleep, cravings and the mod's own systems.
  Combat touches are small (one per axis at most) so personality is felt
  without becoming the new min-max.
- Personality is in modData and exposed by one helper, so the existing modules
  (`DanTraits_Moodles.lua`, `DanTraits_Sleep.lua`, `DanTraits_Smoker.lua`,
  `DanTraits_Alcohol.lua`, `DanTraits_MDD.lua`, `DanTraits_Vitality.lua`)
  each read it in one or two places.
- The diary mod (PZ Chronicle, OnStoryEvent link) gets the four numbers and the
  summary sentence, so the diary speaks in the character's voice.
- Personality can drift: a month of play with low stress nudges Calm, a month
  of heavy drinking nudges Impulsive. Slow, capped at one step from where
  creation put it. Optional, phase 5.

## Latent conditions

- Rolled at creation, stored as `modData.DanTraits.latent[trait] = true`.
- `DanTraits_HasTrait` treats a latent trait as present, so every system runs
  unchanged. The character info panel hides latent traits.
- Each condition module calls `DanTraits_Reveal(trait)` the first time its
  defining event fires (first asthma tier, first aura, first migraine attack,
  first fracture, first craving past the threshold). Reveal adds the real
  trait, drops the latent flag, and says so in halo text ("That headache was a
  migraine. You get those, apparently.").
- Age-gated latents check `DanTraits_AgeBand` at creation and are discarded
  if the band does not match, so there is nothing to carry around.
- Starting Medication does not apply to a latent condition. You did not know,
  so you have none.

## Where it lives

Inside DanTraits, behind a sandbox option, as `DanTraits_LifeStory.lua`
(shared: card data, balance helpers, apply-to-player) and
`DanTraits_LifeStoryUI.lua` (client: the creation page). Reasons: the cards are
almost entirely DanTraits traits, the helpers and the trait-hiding wrap in
`DanTraits_Client.lua` already exist, and the test harness is here. If it
grows a life of its own it splits into a sibling mod that depends on DanTraits
before the Workshop release; that is a file move.

Sandbox (page DanTraits):

| Option | Default | What |
|---|---|---|
| LifeStory | Off | Off, Chosen, Random |
| LifeStoryFreePoints | 3 | free points at the end, 0 to 8 |
| LifeStoryLatents | On | roll latents; Off shows everything (for players who hate surprises) |
| LifeStoryPersonality | On | apply personality effects |

**Random** assigns chapters at creation with no UI and tells you your life
story on the first screen of play. It is the strongest anti-min-max setting
and also the cheapest milestone, because it needs none of the UI.

## UI

B42 creation is `CharacterCreationMain` (name, appearance) then
`CharacterCreationProfession` (profession list left, trait lists middle,
chosen traits right, points top). The mod already wraps that page's
`isTraitEnabled` and `setVisible` to hide the Age traits.

Plan: when Life Story is Chosen, replace the two middle trait lists on
`CharacterCreationProfession` with the chapter panel, and keep the profession
list, the chosen-traits list and the points display exactly where they are.
That is less fragile than inserting a whole new page into the flow, and the
player watches the chosen-traits list fill up as cards go in, which is a good
feeling.

The chapter panel:

- One row per deck the age allows, Upbringing at the top. Each row is a
  horizontal strip of cards (name, one-line flavour, icon). Click to expand:
  full grants and costs, latent shown as "may have: ..." with the chance,
  personality nudges as small arrows.
- Picking a card locks it in and refreshes the later rows (exclusions grey out
  with the reason in the tooltip, as the mod already does for meat and gluten).
- Changing age or profession above clears the rows that no longer apply.
- A "Who you are" strip under the rows: the four axes as short bars and the
  summary sentence, with a left/right nudge on one axis.
- The chosen-traits list on the right shows card-granted traits greyed with a
  padlock; the free points are spent from the vanilla lists in a small
  collapsible under the chapter rows.
- Applying traits goes through the page's own add/remove path so the points
  total, the mutual exclusions and the profession-free traits stay right.

Textures: one 64px icon per card, same style as the trait icons.

## Phases

| Phase | What | Done when |
|---|---|---|
| 1 | Card data as a Lua table, cost table, balance helper, exclusions | `tests/test_lifestory.lua` passes: every card nets -3..+3, no cycle in prerequisites, every referenced trait exists |
| 2 | Apply-to-player, latent flags and `DanTraits_Reveal`, Random mode | New game with Random: traits, skills, meds and latents land; first flare reveals; halo text |
| 3 | Personality plumbing: modData, helper, effects in the six modules | Unit tests per effect; a Calm +2 and an Anxious -2 character diverge in stress over a test day |
| 4 | Creation UI (Chosen mode) | Play-test checklist section: pick, swap, exclusions, age change, free points, padlocks |
| 5 | Polish: Chronicle hook, personality drift, icons, "your story so far" text on first load | Workshop-ready behind the toggle |

Phase 2 is a playable milestone on its own. Phase 4 is the expensive one.

## Testing

- Balance invariant as a test, with the cost table as data, so re-costing a
  trait in the main mod fails the test here rather than quietly unbalancing a
  card.
- Exclusion sanity: no card both grants and excludes a trait; no deck where
  every card is excluded by some Upbringing choice.
- Latent reveal: each condition module's reveal call is exercised by its
  existing test file, one assertion each.
- Personality: numbers in a table, one test per axis per side.
- The in-game checklist gets a Life Story section.

## Open questions

1. **Chosen vs Random as the headline.** Chosen is the recommendation; Random
   is nearly free and some players will prefer it. Ship both?
2. **Combat touches on personality.** Keep the one-per-axis above, or make
   personality purely mood, stress and cravings? Mood-only is safer; the
   combat touches are what make people care.
3. **Free points: 3 or 0?** Zero is purest. Three keeps the "my character"
   feeling. Sandbox-adjustable either way.
4. **Does a card ever grant a vanilla profession trait?** Enlisted next to the
   Veteran profession doubles up. Rule for now: the profession's own traits are
   removed from any card's grants for that profession and swapped for a skill
   level.
5. **Multiplayer.** Creation is client-side and modData syncs, so it should
   just work. Server-side sandbox option, as all the others. Needs a two-client
   test.
6. **Other trait mods.** Life Story only knows its own cards. A trait from
   another mod stays on the free-points list. Document that and move on.
