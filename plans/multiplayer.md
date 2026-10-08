# Multiplayer

Design note, drafted 2026-10-07. Nothing is built. The mod is singleplayer
only today (README, mod.info). This note says what stops it working on a
server, the shape of the port, and the order to build it in.

## Why

People ask for it, and a trait mod that only works alone has a smaller
audience on the Workshop. B42 multiplayer is out, and the game's own Lua now
shows the pattern it expects from mods (below).

## How B42 multiplayer splits the work

What the vanilla Lua shows (`media/lua`, 42.21):

- **The server owns the character.** Stats and body parts are changed on the
  server and then sent to the owning client: `syncPlayerStats(player, mask)`
  (`ISDrinkFromBottle`, `SFarmingSystem:changePlayer`) and
  `syncBodyPart(part, mask)` (`ISApplyBandage`, `ISDisinfect`, `ISRemoveGlass`).
  Admins editing stats from the client send `sendPlayerStatsChange`, so a
  plain client write is not expected to stick.
- **Timed actions run in two halves.** `perform()` runs on the client;
  `complete()` runs on the server and makes the real change
  (`ISTakePillAction:complete` calls `JustTookPill`, then `sendPlayerEffects`
  when `isServer()`; `ISEatFoodAction:complete` calls `Eat`).
- **Items are the server's.** Adds and removes in `complete()` go out with
  `sendAddItemToContainer` / `sendRemoveItemFromContainer`.
- **Per-player clocks run on the server.** `XpUpdate.everyTenMinutes` loops
  `getOnlinePlayers()` when `isServer()`, else `getSpecificPlayer(i)` for each
  local player, and keeps its state in the player's mod data. This is the
  model to copy.
- **Client to server:** `sendClientCommand` → `Events.OnClientCommand`.
  **Server to client:** `sendServerCommand(player, module, command, args)` →
  `Events.OnServerCommand`. Mod data: `player:transmitModData()` exists
  (`ISWidgetTitleHeader`); global data uses `ModData.transmit`.

Some of this is read from code and not yet seen in a game. The spike (step 0)
confirms it before anything is built on it.

## What breaks today

1. **Everything runs for player 0 on the local machine.** The minute and
   ten-minute clocks (`DanTraits.lua` `runClock`) run every system for
   `getSpecificPlayer(0)`. On a dedicated server there is no player 0, so no
   system runs there. On a client they run, but see 2.
   Other `getSpecificPlayer(0)` call sites: core (4), Anger, Attrib, BadDay,
   Blood, Brittle, Concussion, GymRegular, Positives, Sleep, SteadyHands,
   Tinnitus, WoundCare, Telemetry, and `DanTraits_FloorUp` in Util (which
   would write one player's floor flag into another's data on a server).
   Split-screen co-op is broken by the same thing today.
2. **Client writes to stats and body parts get overwritten.** Systems that
   set stats: core, Age, AgeTraits, Anger, Arthritis, Asthma, BadDay, Blood,
   Clotting, Epilepsy, Gluten, Heart, Infection, Knox, MDD, MS, Migraine,
   Positives, Sleep, Smoker, Sunburn, Util (FloorUp, StatAdd, delta pipeline,
   pain floors), WoundCare. Systems that set body parts (bleeding, fractures,
   general health, pain, stiffness, infection): Age, Asthma, BadDay, Blood,
   Brittle, Clotting, Diabetes, Heart, Hemophilia, Infection, Positives,
   Vitality, WoundCare. Expect effects that flicker and snap back.
3. **The delta pipeline fights the server.** `DanTraits_DeltaHook` reads a
   stat each minute, compares it with last minute and rescales the rise.
   Run on a client that is being corrected by the server, it scales the
   wrong numbers. It must run where the stat is simulated.
4. **The eat and pill hooks fire on the server, the systems on the client.**
   `ISTakePillAction:complete` is wrapped in core and `DanTraits_OnEat` hangs
   off the eat action. In multiplayer those run on the server and write the
   server's copy of `modData.DanTraits`; the client systems never see the
   pill. Meds, MDD, Lactose, Gluten, Diabetes, Vitality and Smoker are hit.
5. **Item changes do not persist.** Starting kits (AgeTraits, Arthritis,
   Asthma, Diabetes, Epilepsy, Heart, Migraine, MS, Pill Caddy) and in-play
   changes (Arthritis, MS and BadDay removing or spoiling items, Anger
   wearing a weapon down with `setCondition`) are made on the client with no
   send. Meds' `setUsedDelta` is loot fill (OnFillContainer), which already
   runs where loot is made.
6. **Our own timed actions do their work in `perform()`.** ISDiabetesAction,
   ISUseInhalerAction and ISVitalityPillAction have no `complete()`.
   ISVitalityClotAction has one and already calls `syncBodyPart`.
7. **Some inputs are client-only events.** OnWeaponSwing (Anger, Arthritis,
   Concussion, Tinnitus, WoundCare), OnPlayerAttackFinished (Arthritis),
   OnWeaponHitXp (Anger), AddXP (Age, AgeTraits, Vitality), OnPlayerGetDamage
   (Blood, Brittle, Concussion). Which side each fires on in multiplayer is
   not known yet.
8. **Feedback is client-only.** Moodles (Moodle Framework is client side),
   the Health panel lines, the Pill Caddy tab, sounds, `Say`, halo text,
   Faint's screen and vehicle shut-off (it already sends a `vehicle shutOff`
   client command), Hallucinations. These read `modData.DanTraits`, which will
   live on the server.

Already handled: Telemetry and the dashboard are off in multiplayer,
Hallucinations are off in multiplayer, Deep Sleeper has a multiplayer case,
sandbox options come from the server.

## The decision: who owns the trait systems

**Recommended: the server.** Every system runs on the server for each online
player, the way `XpUpdate` does, and pushes what changed. The client only
asks for things (actions, context menus) and shows things (moodles, panel,
sounds). In singleplayer the "server" is the local game and nothing changes.

- For: one copy of the truth. Stats and body parts are changed where the game
  simulates them. Eat, pill and action hooks already run there. Players
  cannot edit their own trait state.
- Against: every system's feedback has to be sent to the client, and the
  frame-rate systems need a server tick that is known to work.

The other way, the client owns the systems and sends every change to the
server as a command, keeps more code where it is but needs a command for
every stat and body write, still has to move the eat and pill hooks, and lets
a modified client write any stat it likes. Not recommended.

## The shape of the port

### One player loop

A core helper, `DanTraits_ForEachPlayer(fn)`: `getOnlinePlayers()` on a
server, every local player (`getNumActivePlayers`) otherwise, skipping the
dead. `runClock` uses it. On a multiplayer client the clocks do not run at
all (`DanTraits_IsAuthority()` is false). Every `getSpecificPlayer(0)` in a
system goes: the player is passed in. `DanTraits_FloorUp` takes the player
(or `d`) as an argument. Split-screen co-op comes for free.

Frame cadence (`OnPlayerUpdate` today): the spike finds out whether it fires
on the server for each player. If not, a server `OnTick` loop over players
with the frame multiplier.

### One sync layer

Stat and body writes go through Util helpers that change the value and mark
it dirty: `DanTraits_SetStat(player, stat, value)`,
`DanTraits_PartSet(part, field, value)`. After each driver run the core
flushes: one `syncPlayerStats(player, mask)` for the dirty stats and one
`syncBodyPart(part, mask)` per dirty part. In singleplayer the flush is a
no-op. The masks are the game's (`SyncPlayerStatsPacket.Stat_*` and the body
part bit fields vanilla passes as hex); the spike lists the ones we need.

The existing helpers (`FloorUp`, `StatAdd`, `PainFloor`, `PainBurst`,
`HeadPainAtLeast`, the delta pipeline, `DanTraits_Cough`) switch over first;
that covers a large share of the writes. Then the direct `stats:set` and
body-part setters, file by file.

### Server to client: a state message

Once a minute (and when something important happens) the server sends each
player a compact snapshot with `sendServerCommand(player, "DanTraits",
"state", t)`: moodle levels (`DanTraits_MoodleLevels` already builds them),
the Health panel's lines, the age line, Pill Caddy state, whatever the client
UI reads. The client keeps it in a table the UI reads in place of
`modData.DanTraits`. In singleplayer the UI keeps reading mod data directly.

Rule for every UI file: read through one accessor, `DanTraits_ClientData()`,
never `getModData()`.

### Server to client: effects

One command, `"fx"`, with a kind and arguments: play a sound, `Say` a line,
halo text, start a faint, shut off a vehicle, cough sound. Systems call
`DanTraits_Fx(player, kind, args)`; in singleplayer it runs at once.

### Client to server: inputs

Events that only fire on the client and that a system needs (weapon swing,
attack finished, hit XP, maybe AddXP and get-damage) are forwarded with
`sendClientCommand("DanTraits", "input", {...})`, and the server runs the
same handler it runs in singleplayer. Keep the arguments to what the server
cannot see itself, and sanity-check them (a swing needs a weapon in hand).

### Actions and items

- Our four timed actions: the effect moves into `complete()`, item use and
  removal with `sendRemoveItemFromContainer` / `syncItemFields`, body changes
  through the sync layer. `perform()` keeps only the client side.
- The eat and pill wraps stay on `complete()`; they now run where the systems
  are, so nothing else changes.
- Starting kits: granted on the server when the character first exists there
  (the spike finds the event), added with `sendAddItemToContainer`. A flag in
  mod data stops a second grant.
- In-play item changes (Arthritis drops, MS drops, BadDay spoiling, Meds) go
  through one helper that does the change and the send.

### Mod data

`modData.DanTraits` lives on the server and is saved with the character
there. The client does not write it. A grep of `client/` found no writes
outside Telemetry (which is off in multiplayer); the context menus only queue
actions. Anything a client needs to set becomes a client command.

The Health panel reads the *patient's* mod data
(`DanTraits_HealthPanel.lua:81`), so a doctor sees the patient's blood and
wound lines. In multiplayer the patient's data is not on the doctor's
client. Either the doctor's client asks the server for that player's panel
lines when the panel opens (a `"panel"` command), or the panel shows mod
lines only for yourself. Asking is better; it is one command.

## Build steps

0. **Spike (in game).** A hosted server and two clients (`-nosteam` lets two
   run on one PC). Answer and write down:
   - does a stat set from client Lua stick, revert, or reach the server?
   - does player mod data set on the server reach the client, and is it saved
     on the server?
   - which side fires: OnPlayerUpdate (for remote players), OnWeaponSwing,
     OnPlayerAttackFinished, OnWeaponHitXp, AddXP, OnPlayerGetDamage,
     OnCreatePlayer, OnFillContainer;
   - which `SyncPlayerStatsPacket` constants exist and what masks
     `syncBodyPart` takes for bleeding, fracture, stiffness, additional pain,
     health, infection;
   - does Moodle Framework work on a client in multiplayer.
   Results go into this note under "Spike results". Size S to M.
1. **Player loop and authority.** `DanTraits_ForEachPlayer`,
   `DanTraits_IsAuthority`, no more `getSpecificPlayer(0)` in systems,
   FloorUp takes the player. Singleplayer behaviour unchanged; split-screen
   starts working. Tests: two local players do not share state.
2. **Sync layer.** Dirty-marking helpers and the flush. Switch the Util
   helpers, then every system's direct writes. Tests: the harness records
   `syncPlayerStats` / `syncBodyPart` calls and checks each write is flushed.
3. **State message and client accessor.** Moodles, Health panel, Pill Caddy
   tab and age line read `DanTraits_ClientData()`.
4. **Effects channel.** Sounds, speech, halo text, faint, cough, vehicle.
5. **Actions and items.** `complete()` for our actions, server starting kits,
   the item helper.
6. **Inputs.** Forward the client-only events found in the spike.
7. **Per-system review.** Systems whose rules assume one player and pausable
   time: Sleep (no fast-forward in multiplayer; Early Riser, Night Shift and
   the sleep score), Deep Sleeper, A Really Bad Day (world searches and the
   start kit), Age on the creation screen (reads sandbox each frame),
   Hallucinations (stay off, or client-only later), Germaphobe and Fear of
   Blood (corpse and blood scans near the player: fine on the server, check
   the cost with many players).
8. **Two-client test pass.** A checklist section of its own, both players
   with overlapping traits, a reconnect, a server restart, a death and a new
   character. Then README, mod.info and the Workshop text drop
   "singleplayer only".

Each step leaves singleplayer working and is committed on its own.

## Tests

The offline harness gets a multiplayer mode: `isServer()` true,
`getOnlinePlayers()` with two players, and recorders for `syncPlayerStats`,
`syncBodyPart`, `sendServerCommand`, `sendAddItemToContainer`. New checks:

- no system reads `getSpecificPlayer` (a grep test, like the key-prefix one);
- two players with the same trait keep separate timers and floors;
- every stat or body write in a driver run is followed by a flush with the
  right mask;
- a client (`isClient()` true) runs no driver;
- a pill taken by player B only changes player B.

The existing singleplayer tests stay green at every step.

## Size and risk

L, a few weeks of sessions. Risk high: it touches nearly every file, and the
risk is to singleplayer, not just to multiplayer. That is why each step
keeps singleplayer identical and lands alone. Best as its own release after
Age v2 ships, not mixed into it.

## Out of scope

- Dan's Vanilla Fixes (coolers, hand washing, rarity UI) is a separate mod
  and needs its own pass; the washing patch already has a client file.
- PZ Chronicle's `OnStoryEvent` link: client side by design, revisit when
  the bridge is built.
- Project A-Life compat: check once A-Life itself supports multiplayer.

## Open questions

1. Server ownership (recommended) or client ownership?
2. Is split-screen co-op worth testing as its own target? It falls out of
   step 1.
3. Should other players see your symptoms (a cough, a faint, a seizure)? The
   game syncs animations it knows; sounds would need the fx message sent to
   nearby players too.
4. Hallucinations in multiplayer: stay off, or a client-only version later?
5. Health panel on another player: ask the server for their lines
   (recommended), or show mod lines only for yourself?
6. Which release carries it?

## Spike results

Not run yet.
