# Minds for Project A-Life NPCs

Design note, drafted 2026-10-11. Nothing is built. Personal use only, not
for the Workshop. Comes after the PZ Chronicle bridge, which it shares.

The idea: Project A-Life already owns the bodies (pathing, combat, outposts,
loot, a free-text chat box, speech over the head, per-NPC memory saved with
the world). We attach a mind: a character sheet rolled from our own trait
registry, a personality, a memory of what has happened, and an LLM that
turns the sheet plus the player's words into a reply and a small change of
state. The model talks freely and acts only through verbs A-Life already
has, so the bodies stay on A-Life's rails.

## What A-Life has (read 2026-10-11, v1.3.15, Workshop 3803984183)

Paths under `mods/ProjectALifeNPCs/42.20/media/lua/`.

- **Free-text chat.** `client/ProjectALife/Talk/ALifeTalkInput.lua`: a text
  box in single player (`singlePlayerChat = true`). Every line goes to
  `ProjectALife.Talk.onPlayerText(player, text, loud)` in
  `server/ProjectALife/Talk/ALifeTalk.lua`, which finds listeners within
  `listenRadius` (12 tiles, 60 degree cone), picks an addressee and calls
  `Talk.respond(player, listener, text, now, choiceIntent)`. A choice menu
  (`ALifeTalkMenu.lua`) sends the same path with an intent already chosen.
- **Intents.** `shared/ProjectALife/Talk/ALifeTalkIntents.lua`:
  `Intents.classify(text, pendingAnswer, data)` matches keywords to about 25
  ids (GREETING, ASK_NEWS, ASK_DESTINATION, ASK_ADVICE, ASK_FOOD,
  ASK_JOB_BEFORE, ASK_MILITARY, ASK_FORT_KNOX, ASK_WHAT_HAPPENED, ASK_RADIO,
  ASK_DANGER, TELL_STORY, ASK_FAMILY, ASK_GROUP, ASK_MISS, ASK_WATER,
  ASK_MEDS, ASK_LOOT_SPOT, JOIN_REQUEST, COME_WITH_ME, YES, NO, ...).
  Unknown text returns nil.
- **Replies.** Authored banks under `shared/ProjectALife/Talk/Data/`
  (`ALifeDialogue_talk_*`, `_barks_*`, `_scenes_*`, `_radio_*`), picked by
  `Speech.pick` against a context (stance, temperament, register, facts) and
  rendered with `Speech.render(text, vars, shell)` (town names, callsigns,
  the clock). Multi-beat lines run through `Talk.sequence` /
  `Talk.advanceSequence`.
- **`Talk.respond`, the seam** (ALifeTalk.lua line 361 in 1.3.15). In order:
  combat check (busy bark), classify, hostile stance (ignore bark), hold and
  face the player, `intent == nil` -> fallback barks TALK_FALLBACK_1/2/3/END
  with a miss counter, pending YES/NO answers (`Talk.accept` on yes:
  joining, following), `TalkSupplies.respond` for ASK_FOOD/ASK_MEDS (hands
  items over), COME_WITH_ME refusal for fresh temperaments, `Talk.escalate`
  for provoking intents, then `Talk.speak` from `data.replies[intent]`.
  Returns `(said, outcome)` where outcome is one of busy, hostile, unknown,
  answered, refused, scripted, no_reply.
- **Speech.** `shared/ProjectALife/Talk/ALifeSpeech.lua`:
  `Speech.say(shell, text, { face = player, earshot = n })` draws the line
  over the shell with `addLineChatElement` in the faction colour, in single
  player directly, on a server by sending "speech" to players within
  earshot. `AudioPolicy.caption` filters the text; `maxTextLength` is 200.
  `Speech.remember(uid, playerKey, text)` keeps a recency ring so lines are
  not repeated.
- **Per-NPC memory, persisted.** `server/ProjectALife/Core/ALifeActorRegistry.lua`:
  every actor is a record `{ uid, revision, generation, lifecycle,
  profileId, factionId, worldPosition, activity, intent, memory = {} }`,
  saved with the world. `Talk.writeMemory(uid, function(memory) ... end)`
  (ALifeTalk.lua line 209) is the guarded writer; it bumps the revision and
  tells the decision loop when conversation state changed. Our sheet lives
  in `memory.mind`, nowhere else.
- **Character state to seed from.** `Decisions/ALifeRisk.lua`:
  temperament per actor (fresh, veteran, predator, ...).
  `Decisions/ALifeReputation.lua` and `ALifeRelations.lua`: per-player
  reputation, stance (`Relations.playerStance`), grudges
  (`memory.hostileToActorKeys`), `Reputation.escalate(player, actor, deed)`.
  `Talk/ALifeRumors.lua`: generated rumours with towns and dens.
  `Talk.observations(record, shell, player, now)`: what the NPC can see of
  the player (armed, aiming, bloodied, hands up). `Speech.nearestTown`,
  `Talk.destinationFor`, `Talk.denFor`.
- **Authored characters.** `shared/ProjectALife/Records/ALifeCustomProfiles.lua`
  and the Creator UI (`client/.../Creator/ALifeCreatorCore.lua`): name, sex,
  faction, appearance, loadout, a "Text-only personality" caption, saved to
  `alife_server_profiles.ini` with the game's file writer. So authored minds
  can start from a profile; and file I/O works without debug mode.
- **Behaviour extension.** `shared/ProjectALife/Behaviours/ALifeModuleRegistry.lua`:
  `ModuleRegistry.register` with kinds doctrine, orders, reaction, craft,
  upkeep, priorities per overlay. Not needed in version 1.
- **Events it fires.** None as Lua events. Seams are the client handlers and
  `sendServerCommand("ProjectALife", ...)` (MetaEvent, supportArrival,
  talkResult, reputationSync, raid), called directly in single player, and
  `Registry` emits `actor_created` internally. Our hit measuring already
  wraps `Combat.resolveAttack`, `ModuleGunner.grazePlayer`,
  `Executor.woundPlayer` (DanTraits_ALife.lua).
- **Rules.** Any mod with Lua under a `ProjectALife/` folder is flagged
  incompatible. Wrap by table (`ProjectALife.Talk.respond = ...`), never by
  the event reference. Talk runs only where `Speech.authoritative()` is true
  (single player, or the server).

## The shape

### The sheet (`memory.mind`)

Rolled on the first conversation with an actor that has none, or authored
from a custom profile's caption. Validated on every write; the model never
writes it directly.

```
mind = {
  v = 1,
  name, age (20s/30s/40s/50s band), job_before,
  traits = { "arthritis", "spiraling", "base:brave" },   -- 2 or 3 from DanTraitsRegistry + vanilla
  personality = { warmth, trust, nerve, humour, talk },  -- 0..1 each (Life Story axes)
  mood = 0..1, trust = { [playerKey] = -1..1 },
  goals = { "get to Louisville", "find insulin for Mara" },
  facts = { "lost a brother at the Knox checkpoint", ... },   -- authored or model-remembered, capped
  log = { { day, who, text }, ... },                           -- last 12 exchanges
  seenPlayer = { "passed out in a kitchen", "shot Ray" },     -- from OnStoryEvent + A-Life events
}
```

### The loop

1. `Talk.respond` is wrapped (tag `alife-mind`). Before calling the original:
   if the actor has a mind and the setting is on, and either the intent is
   nil (A-Life has nothing to say) or the "always" option is set, build a
   request and return a filler at once (`Talk.bark` TALK_FALLBACK_1 style:
   a look, "Hm.", "Give me a second."). Otherwise call the original.
   Hostile stance and combat are left to A-Life entirely.
2. The request is written to `Zomboid/Lua/alife_mind_request.json` with the
   file writer (the Chronicle export does the same): `{ id, uid, player,
   text, sheet, context }` where context is A-Life's own `contextFor`,
   stance, temperament, observations, nearest town, destination, the two
   newest rumours, in-game date and time, and the last few lines from
   `mind.log`.
3. The bridge (the Chronicle watcher, a second route) builds the prompt and
   calls Claude with a strict schema, and writes
   `alife_mind_reply.json`: `{ id, say = { "line", "line" }, mood,
   trust_delta, remember = "...", intent = "JOIN_REQUEST" | nil,
   emote = nil }`. Lines are capped at 180 characters each, two at most.
4. A tick (`Talk.later` or our own minute driver at frame cadence) polls the
   reply file. On arrival: find the shell (`Talk.shellFor(uid)`), say the
   lines through `Talk.sequence` so they come one after another facing the
   player, apply the deltas through `Talk.writeMemory`, append to `mind.log`.
   If `intent` is set, call the original `Talk.respond(player, listener,
   "", now, intent)` so A-Life performs the verb (join, follow, hand over
   supplies, refuse, escalate). That is the only way the model touches the
   body.
5. No reply within 8 seconds, or the bridge is down: a second filler and
   the original respond runs with the player's text, so A-Life's own banks
   answer. Nothing is ever stuck waiting.

### What the model is told

The sheet, the context, and the rules: stay under 180 characters a line,
never invent a place, person or event not in the context or the sheet,
speak like a 1993 Kentucky survivor of this temperament and these traits,
and return only the schema. Trait flavour comes from our own registry
descriptions (an Alcoholic asks for a drink, Arthritis complains of the
damp, Spiraling is flat). The rolling summary pattern from Chronicle applies
per actor: once `log` is full, the bridge folds the oldest entries into
`facts`.

### Feeding the mind

- **The player's story:** `OnStoryEvent` already carries every DanTraits
  notice. Keep the last day's worth in a ring; when a conversation starts,
  the ones the NPC could plausibly know (same building, within earshot, or
  anything if the NPC has followed the player for a day) go into
  `seenPlayer`.
- **A-Life's story:** wrap the single-player client handlers for talkResult,
  raid, MetaEvent and reputationSync, and reuse the hit wraps in
  DanTraits_ALife.lua, so "you shot Ray" and "the raid on the motel" land in
  the sheets of actors who were there (same faction, within 30 tiles).
- **Time:** once a day, idle actors with a mind get one cheap "what did you
  do today" call with no player text, so goals and mood move while you are
  away. Capped at a handful of actors a day, nearest first.

### Rolling a mind

On first contact: age band by A-Life temperament (fresh skews 20s, veteran
40s/50s), 2 or 3 traits from `DanTraitsRegistry` plus vanilla, weighted away
from the ones that need a body system we cannot drive (Diabetes is fine as
flavour, Hemophilia too, but nothing that would expect a kit). Personality
axes from the Life Story design. Name from the shell's A-Life name if it has
one, else a period name list. Authored profiles: the personality caption
becomes `facts[1]` and the traits are read from the caption if they name any.

## Build steps

1. **Chronicle bridge first** (the watcher, the Claude call, the reply
   writer). This plan adds one more request type to it.
2. **Sheet and roll.** `DanTraits_ALifeMind.lua` (or a separate private mod
   that depends on both): `Mind.of(uid)`, `Mind.roll(record, shell)`,
   `Mind.validate(delta)`, `Mind.apply(uid, delta)` through
   `Talk.writeMemory`. Offline tests with a fake registry.
3. **The wrap.** `Talk.respond` wrapped by table at OnGameStart with a log
   line like the phantom guard's (`[DanTraits] A-Life minds on: respond
   true, speak true`). Filler, request file, poll, say, verb hand-off,
   timeout fallback.
4. **One NPC.** A custom profile with an authored caption. Ask it something
   off the intent list; sleep; ask it tomorrow whether it remembers.
5. **Feeding.** Story events in, A-Life events in, the daily idle call.
6. **Rolled minds for everyone** behind a setting, with the per-day cap.

## Size and risk

- Lua: a few hundred lines (sheet, wrap, poll, feed). Bridge: about a
  hundred lines on top of Chronicle's. Days of work, not weeks, because
  A-Life did the 60,000 lines that matter.
- A-Life updates can move or rename `Talk.respond`, `Talk.speak`,
  `Talk.writeMemory`, `Speech.say`. The log line at start says which were
  found; a missing one turns the feature off cleanly.
- Latency 2 to 5 seconds a line; the filler bark covers it. Cost a few
  cents a conversation; the daily idle call is the one to cap.
- Drift: the sheet is the truth, every delta validated and clamped, and the
  model only ever sees facts A-Life or the sheet already hold.
- Single player only. A-Life's talk is server-authoritative, so on a server
  the bridge would have to run beside the server.

## Out of scope

New behaviour modules, NPC-to-NPC conversations through the model (the
rumour and gossip systems already cover that cheaply), voice, anything the
Workshop would need (keys, a shipped bridge).

## Open questions

- Always through the model, or only when A-Life's classifier has nothing?
  Start with "only when nothing", since the authored banks are good and
  free, and the model is the long tail.
- Should a mind's traits ever reach the body (an Arthritis NPC flaring in
  the cold through A-Life's healing module)? Later, through
  `ModuleRegistry`, if the first version is fun.
- Which Chronicle component makes the call: the Express server or the
  dashboard script? Whichever the bridge settles on; this plan does not
  care.
