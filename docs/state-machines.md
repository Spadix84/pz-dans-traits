# State machines

Most systems in the mod carry a phase in a few mod-data keys: an attack flag, a stage
number, a countdown that is nil between episodes, a `"pending"` string. Nothing in the
keys says which combinations are legal, what ends each phase, or who else reads them.
This page is the map. It was surveyed on 2026-11-09 across every file in the repo:
DanTraits, the sibling mods, client and core.

## The seam: `DanTraits_Machine`

A system declares its phases once, in its own file next to the keys
(`DanTraits.lua`, "Declared state machines"):

```lua
DanTraits_Machine("strain.breakdown", {
    states = { "none", "pending", "active" },        -- the rest state first
    on = function() return strainOn() and DanTraits_SandboxOn("StrainBreakdown") end,
    of = function(player, d) return d.stBreak, { strain = d.strain } end,   -- reads, never writes
    load = function(player, d)                         -- a ready step at 15
        if d.stBreak == "active" then d.stBreak = "pending" end
    end,
})
```

Each consumer reads the declared state instead of decoding the keys itself:

| Who | How |
|---|---|
| Another system | `DanTraits_StateOf(player, "migraine.attack") -> "aura", { hoursLeft = 0.4 }` |
| The companion app / an agent | Telemetry JSON `machines`: `{ "migraine.attack": { "state": "aura", "info": {...} } }` |
| The console (debug) | `states` (machines not at rest), `states all` |
| The tests | `tests/test_machines.lua` reads every machine. STRICT raises on a state the spec doesn't declare. |
| This page | `tests/check_machines.py` fails if a declared id is missing from the table below, or if the table lists one that no longer exists. |

The rules:

- **Keys and save format are unchanged.** A machine reads the owner's keys and never
  writes them, except `load`.
- **A gate applies before the reader runs.** With `trait`, a character without the trait
  reads as the rest state, whatever stale keys say. With `on` switched off (the sandbox),
  it also reads as rest.
- **An undeclared state is a bug.** It is logged once and read as rest. Under STRICT (the
  tests) it raises.
- **`load` is for states that cannot outlive a save.** A timed action in progress is not
  saved, so any state that only the action's `stop`/`perform` ends needs one. `load` runs
  twice per load, like every ready step, so it must be idempotent.

New multi-phase systems declare a machine. Existing undeclared ones (below) are declared
as they are next touched.

## Declared

| id | owner | states (rest first) | keys | gate |
|---|---|---|---|---|
| `adhd.focus` | ADHD | idle, building, hyperfocus | adhdFocus, adhdHyper | trait adhd |
| `adrenaline` | Adrenaline | calm, rush, returning, crash | adRushMin, adRetMin, adCrashMin (adAttackIn in info) | none |
| `asthma.airway` | Asthma | clear, irritated, attack | asthma, asthmaAttack | trait asthma |
| `caffeine.withdrawal` | Caffeine | sated, withdrawing | cafWithdrawing, cafDryHours, cafWithdraw | trait caffeine |
| `concussion.late` | Concussion | none, waiting, headache | ccLate {wait} / {left} | ConcussionEnabled |
| `dependent.withdrawal` | Dependent | none, craving, shakes, delirium | alcWithdrawing, alcStage | trait dependent |
| `epilepsy.seizure` | Epilepsy | idle, aura, aftermath | epAuraMin, epAfterMin | trait epilepsy |
| `fever` | Fever | none, fever, dangerous | fevRaw, fevDanger | none |
| `germaphobe.grime` | Germaphobe | clean, filthy | gmFilthy, gmGrime | trait germaphobe |
| `gluten.flare` | Gluten | none, onset, flare | glutenOnset, glutenPending, gluten | trait gluten |
| `gout.flare` | Gout | calm, flare | gtFlareMin | trait gout |
| `hangover` | Hangover | none, drinking, pending, hungover | hoDrinking, hoPending, hoActive | HangoverEnabled |
| `heart` | Heart | calm, angina, weakened | hcAnginaMin, hcWeakH | none (the weak week is for anyone) |
| `illness` | Illness | well, incubating, sick | ill[id] {inc} / {t,...} | IllnessEnabled |
| `infection` | Infection | none, contaminated, local, fever, sepsis | infStage | InfectionEnabled |
| `lactose.flare` | Lactose | none, onset, flare | lacOnset, lacPending, lacFlare | trait lactose |
| `mdd.episode` | MDD | well, episode, recovering | mddEpisode, mddSinceEnd | trait spiraling |
| `migraine.attack` | Migraine | clear, aura, attack, refractory | migAuraLeft, migActive, migSinceEnd | trait migraine |
| `ms.flare` | MS | calm, flare | msFlareH | trait ms |
| `sensory.load` | Sensory | calm, loaded, overloaded, meltdown, shutdown | siTier, siOver, siLoad | trait sensory |
| `strain.breakdown` | Strain | none, pending, active | stBreak | StrainEnabled and StrainBreakdown; `load` |
| `vitality.night` | Vitality | awake, asleep, between | vitAsleep, vitNightHours | VitalityEnabled |

## Not declared yet

These are still implicit. Their state is in Telemetry's raw `mod` only (or nowhere,
for item, object and Lua-only state).

- **Health:** Smoker (continuous, in the game's NICOTINE_WITHDRAWAL stat), Meds (per drug:
  building, covered, side effect, overdose), Diabetes glucose tiers and its one wake per
  low, Knox, Tinnitus, WoundCare and Clotting (per part), Spoons, Arthritis morning,
  CarpalTunnel numbness, Hemophilia reopen clock, Faint (a Lua-only hold).
- **Everyday:**
  - Fitness: session, Pumped, Loosened Up, Overtrained, the plan, Newbie Gains.
  - Others: Cooking's meal, Sleep's segment and night, Home, AgeTraits (Bad Back, Bad Knees,
    Settled), AgeWants, Reading's moodle (`DVF_Reading`).
  - Item and object state: Laundry per garment (item `DTL`), the washer and dryer watch,
    the Hot Water Bottle (item `dtHwb*`).
  - SleepMenu's undress record, Bathing's mode (Lua-only).
- **Creation one-shots:** Hunted, Swarmed, Robbed, Wounded and Bad Day's `*Done`/`*Applied` flags.
- **Core:** the ready sequence (idempotent by design), the trait-gate latch `entry.had`, the
  frame-set stamp, the `DanTraits_Later` queue, the guard-failure latch.
- **Sibling mods:**
  - Base Unloader's run (`R.active`: pending, inStep, stepDone).
  - Vitality Challenges' per-world latches and Last Broadcast's show.
  - Vitality Cartridges' modes (explicit), Dans Climate's on/off in the sprite index,
    Map Legend's `own`.

## Defects the survey found

### Fixed (2026-11-09, each with a test)

| What | Where | Test |
|---|---|---|
| A save made mid-breakdown, or a queue cleared without the action's stop, left `stBreak = "active"` for good: strain never eased, held at 100 with the moodle at 4 | Strain `settleBreakdown`, machine `load` | test_strain 15b |
| Any fever (most illnesses carry one for their whole course) stopped the asthma easing, so an attack could not end without the inhaler. Fever now eats into the easing and builds only past it, as Heart's cold does | Asthma minute | test_asthma 15 |
| A wound that closed during incubation still turned "infected" for a minute, with its notice | Infection `updatePart` | test_infection 9c |
| A full caffeine dose left `cafWithdraw` set until the next minute, read by Migraine and Steady | Caffeine `dose` | test_caffeine 5c |
| Alcoholic removed by the console or another mod: the withdrawal keys stayed, so Steady kept shaking | Dependent minute | test_alcoholic (end) |
| Vitality switched off asleep before the first scored night: the sleep's start stayed, and switched back on, every hour since counted as one night | Vitality off branch | test_vitality (sandbox) |
| Reading switched off with a genre buff running: the XP multiplier stayed on, past its end, for as long as Reading was off | Reading `everyMinute` | test_reading (XP buff) |
| The 50s' same-bed sliver was paid once a save, not once a day (`awBedTouch` never reset) | AgeWants `rollDay` | test_agewants 4 |
| Base Unloader: a step that threw left the run "running" with nothing to move it on. It now pauses, and the plan is kept for Resume | BaseUnloader_Run `onTick` | test_baseunloader (end) |

### Open, by how much a player meets them

Confirmed means traced in the code. Suspected means it rests on engine behaviour not checked.

1. **Night flags that only Vitality clears.** Epilepsy's `epNight`, Diabetes' `diaNightLow`
   and Home's `hmNightLoc` are consumed only when Vitality scores a night. With Vitality off
   they stay forever, and the first night after switching it back on is penalised or filed
   against an old place. They need one owner of "the night was dropped". (Confirmed.)
2. **Fitness off keeps the plan but wipes the log.** Back on, every target day while it was
   off reads as missed. (Confirmed.)
3. **Laundry's poncho baseline goes stale.** Take the poncho off, get bloody, put it back on:
   the next minute removes the blood gained while uncovered. (Confirmed.)
4. **The Hot Water Bottle keeps its warmth on the floor.** A bottle neither carried nor
   heating is not counted down, then charged the whole gap at the pickup moment's rate.
   (Confirmed.)
5. **Settled's new-bed penalty is lost on an interrupted night.** `stChecked` is reset each
   awake minute, so the second segment reads the bed as old. (Confirmed.)
6. **SleepMenu: a second Undress and Sleep overwrites the open record.** The first
   record's dropped items are forgotten and their favourite flag is never restored.
   (Confirmed.)
7. **Vitality Challenges add their clock handlers on every world load.** A second load
   in one session runs every challenge hook twice, and in a non-challenge world.
   (Confirmed.)
8. **Telemetry for agents:**
   - The JSON is overwritten in place, so a reader can catch half a file.
   - Lines appended to the command file between the read and the truncate are lost.
   - Commands carry no id, and the only reply is a text line in `log`.
   - Death and the main menu stop the writes with no marker; judge staleness from `t`.
   - `log` and `story` carry over between saves in one session.
9. **Illness exits differ.** One illness switched off deletes its record with no immunity.
   The master switch keeps every record. (Confirmed.)
10. **The health panel ignores the Concussion and Infection switches** and shows frozen
    values. (Confirmed.)
11. **Faint holds one pass-out for everyone.** Split-screen, a second player cannot faint.
    Adrenaline's heart attack can stagger a sleeping character. (Suspected.)
12. **Smaller:**
    - Lactose/Gluten restart the onset in one edge minute.
    - Grit's and Alcohol's pain-reduction shares can drift.
    - Bathing reads "BATH" after a load mid-shower.
    - Swarmed sets `swDone` before the fill, so a failed fill is never retried.
    - The Notes tab is decided once per window.
    - AgeWants applies `vitSleepDebt` after Vitality picks the notice tier.
    - A Lactose/Gluten notice is given on every dose, not only the first.
13. **Suspected, not traced into the engine:**
    - A Smoker removed by the console keeps the game's withdrawal stat.
    - A hallucinated phantom saved mid-charge persists.
    - `DanTraits_Later` jobs and stale UI singletons (What's New, Base Unloader's Stock and
      Zones) carry over an exit to the menu.
    - Last Broadcast settles a show still on air as missed.
    - An unloaded washer stays watched.
