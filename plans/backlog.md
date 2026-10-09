# Backlog

Every idea lands here first. A release plan (`plans/<version>.md`) picks from it;
anything not picked waits. Size: S (an evening), M (a few sessions), L (a design
doc first). Risk: how likely it is to break something already working.

## Open

| Item | Source | Size | Risk | Why |
|---|---|---|---|---|
| Sleep mask: an item that makes a lit room count as dark for the sleep score | Reddit | S | Low | Lit rooms punish sleep with no counter but curtains |
| Illnesses without a trait: cold, flu, food poisoning, diagnosed from symptoms | Reddit | L | Medium | Health that surprises you, not just health you chose |
| Life Story, phase 2: Random mode, no UI (see `life-story-design.md`) | Design doc | L | Medium | Characters that feel like people, not solved builds |
| WoundCare: swapping a bandage for a rag within a minute gives the rag the bandage's life | Review 2026-10-02 | S | Low | Wrong item state |
| Arthritis: a weapon saved mid-swing keeps 0.35x damage until swung again | Review 2026-10-02 | S | Low | A weapon stays weak across a reload |
| Migraine: moodle and migActive stick if the trait is removed mid-attack | Review 2026-10-02 | S | Low | Stuck moodle |
| A Really Bad Day: the kit search scans 121x121x3 squares at game start | Review 2026-10-02 | S | Low | One-off stall on a new game |
| A Really Bad Day: balance pass (plan 21, deferred) | Review programme | M | Low | Deferred until played more |
| Dice: move the hand-rolled ZombRand dice to DanTraits_Roll/RollPercent (Sleep, Migraine, MDD, Jinxed, Dependent, Arthritis, Brittle; tests change with them) | Review 2026-10-02 | M | Low | One way to roll |
| Diabetes and Vitality minute handlers: a constants table before they hit Kahlua's 60-upvalue cap (~50 and ~46 now) | Review 2026-10-02 | M | Low | They break the moment they grow |
| Age v2: everyday effects, a 50s band, re-pricing, visible age, creation-screen levels (see `age-v2.md`) | User | L | Medium | Age is a real choice and felt every day |
| Multiplayer: server-run systems, a sync layer, client state and effect messages (see `multiplayer.md`; spike first) | User | L | High | Singleplayer only today; split-screen co-op is fixed on the way |

## Built, waiting for a play test

| Item | Where | Notes |
|---|---|---|
| Collection checklist: a sidebar window per character to tick off the skill books, magazines, VHS tapes, CDs, key rings, mementos and tools you own; ticking sets vanilla Unwanted | Dan's Vanilla Fixes (`DansVanillaFixes_Collection.lua`, `client/DansVanillaFixes_CollectionUI.lua`, `client/DansVanillaFixes_CollectionClient.lua`) | 2026-10-09. Design `collection-checklist.md`. Tests `test_collection.lua`. Checklist `dvf-col-*` (section 18). Deployed, uncommitted |
| Hand washing has floors: blood and dirt only come down to 40% without soap, 20% with; washers and combo washer/dryers still clean fully | Dan's Vanilla Fixes (`DansVanillaFixes_Washing.lua`, `DansVanillaFixes_WashingClient.lua`) | 2026-10-03. Sandbox WashFloorNoSoap/WashFloorSoap. Tests `test_washing.lua`. Checklist `dvf-wash-*` (section 18). Deployed, uncommitted |

## Parked

| Item | Why parked |
|---|---|
| Fructose Intolerance | Left out by the user, 2026-10-03 |
| Evolving Traits World compatibility (and other mod compat) | Not now, 2026-10-03 |
