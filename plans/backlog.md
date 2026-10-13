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
| Mod pack: pick a solid set of mods the user plays with, publish a Steam Workshop Collection crediting and linking every author, plus Vitality, Dan's Vanilla Fixes and one patches mod that requires the others and loads after them. Others' files are never re-uploaded (that needs each author's written permission). Candidates for the patches mod: the compat files that fix other mods (This Is Your Life, Bandits, A-Life, Take A Bath And Shower stay in Vitality/DVF where they hook our own systems), Bravo Item Details' bare `%` tooltip, and This Is Your Life's MP spawn cleanup deleting A-Life NPCs. First step: the mod list and a compat pass over it | User 2026-10-11 | L | Medium | One tested setup to play and share, with fixes kept on our side |
| Music overhaul, personal only (not for the Workshop): the game drives the user's real Spotify. Lua can't reach the network and Spotify's DRM rules out piping audio into the engine, so the mod writes commands to `~/Zomboid/Lua/` and a small Python companion calls the Spotify Web API (Premium, a personal dev app) and writes now-playing back. Ideas: Walkman, CD player and radio act as the remote (on/off/volume); a base stereo whose volume falls with distance and cuts out outside the building; the stereo makes in-game noise that draws zombies; mood playlists (calm looting, tense with zombies near, night), fading out for sleep and pausing on the pause menu; now playing on the tooltip or HUD and in PZ Chronicle; Deaf/Hard of Hearing hooks. Option: the user's own MP3s as `.ogg` cassettes/CDs for real positional sound (the True Music route). First step: a spike where a Walkman toggle pauses and resumes Spotify | User 2026-10-12 | M | Low | The user's own music in the game, reacting to what happens |

## Built, waiting for a play test

| Item | Where | Notes |
|---|---|---|
| Collection checklist: a sidebar window per character to tick off the skill books, magazines, VHS tapes, CDs, key rings, mementos and tools you own; ticking sets vanilla Unwanted | Dan's Vanilla Fixes (`DansVanillaFixes_Collection.lua`, `client/DansVanillaFixes_CollectionUI.lua`, `client/DansVanillaFixes_CollectionClient.lua`) | 2026-10-09. Design `collection-checklist.md`. Tests `test_collection.lua`. Checklist `dvf-col-*` (section 18). Deployed, uncommitted |
| Laundry: hand-wash and washboard floors (moved from Dan's Vanilla Fixes), wringing leaves clothes damp, musty and stale clothes (moodle), set-in stains and bleach, fabric wear, dry by the fire, clotheslines (map and built), ponchos and fabric protector shield clothes; sandbox split into four Vitality pages | Vitality (`DanTraits_Laundry*.lua`, `ISLaundryAction.lua`, `client/DanTraits_LaundryClient.lua`, `server/DanTraits_LaundryMap.lua`) | 2026-10-11. Design and as-built notes `laundry.md`. Tests `test_laundry.lua`. Checklist `ln-*` (section 19). Deployed, uncommitted |

## Parked

| Item | Why parked |
|---|---|
| Fructose Intolerance | Left out by the user, 2026-10-03 |
| Evolving Traits World compatibility (and other mod compat) | Not now, 2026-10-03 |
