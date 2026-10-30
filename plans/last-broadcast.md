# The Last Broadcast — design draft (2026-10-28)

A Vitality Challenges scenario (`VitalityChallenges_LastBroadcast.lua`). Nothing is
built yet; this is for talking through. Open decisions are marked **[decide]**.

## The pitch

Day one. The Automated Emergency Broadcast is the only thing left on the air, and it
is a loop. You were the night engineer at a small radio station. The staff are gone.
The transmitter still works, the generator has fuel for a few days, and somewhere
out there people are sitting in the dark with a radio, waiting for someone to say
anything.

**Keep the station on the air for 30 days.** Every broadcast is a promise kept to
people you will never see — and a beacon for everything that hears it.

What makes it fun, in one line: **a survival base with a schedule, an audience that
talks back, and a reason to leave the base.** Most PZ runs drift once the base is
built. This one has an appointment every evening, and the listeners keep sending
you out into the world.

## Decided (2026-10-28, with the user)

- **The station is the whole game.** You should never stray far from it. Day trips
  are short; the world comes to you (donations, callers), not the other way round.
  Far-off dead drops are out.
- **One show a day at 18:00.**
- **Donations at the entrance.** Grateful listeners and callers leave supplies in a
  crate at the station's entrance: sometimes gasoline, food, weapons. What turns up
  leans toward what the base is low on or out of (see "The donation crate").
- **Start in Riverside** (lean, not final): reach the station, then keep it on air for
  a month. The walk in is the first act.
- **Callers are all scripted**: a whole narrative of characters and events, but
  flexible: beats react to the weather, the show, what you have and what you did.
- **Station: Jackie Jaye's studio, south Louisville (12482, 3912)** — the user
  checked it on the map and it works. Wanted: enough nearby to scavenge at first
  without being overrun.
- **Set two weeks in (day 14)**: in vanilla lore the stations keep going for a while;
  all but TURBO are gone by day 13.
- **Start in the small lakeside house at 12240, 3683** (cell 47_14; a one-storey
  house on a dead-end road by the water, about 270 tiles west of the studio). The
  station is **not** handed to you: it starts with its dead inside, and you earn it
  by clearing it.
- **Power and water are off** from the start.
- **Win: 30 shows, never more than 2 days between shows.** A gap longer than two
  days **fails the challenge** (the summary, "failed" in the record), but the game
  carries on: the station is still yours to keep running.
- **One life.**
- **8 caller threads** at launch.
- **Your character speaks on air**: the show's lines appear over their head as well
  as on the radio.
- To dial in by play: the beacon (noise radius, horde size) and donation generosity.

## The station: Jackie Jaye's studio, south Louisville (chosen 2026-10-28)

Found in the map's room data: a room named `jackiejayestudio` (2x3, ground floor,
12482–12483, 3912–3914) with `jackiejayeoffice` beside it (12480, 3908, 4x4) and a
bathroom, in an office block. Jackie Jaye is vanilla lore: "This is Jackie Jaye
reporting for LBMW..." and the author of "Breaking News" and "Jackie Jaye -
Truthseeker!". **LBMW - Kentucky Radio is the first vanilla station to go off air
(its broadcasts run days 0–7).** Every other vanilla station is gone by day 11
(Triple-N TV day 13; only TURBO lasts to day 27). So **start on day 14: the dial
has been silent for days, and you put LBMW's reporter's studio back on the air.**

Why this one, by the room counts (ground-floor rooms within a square radius):

| Radius | Rooms | What's there |
|---|---|---|
| 200 | 74 | an industrial/office strip: offices, a server room, a morgue, a Pizza Whirled, a Spiffo's, a burger kitchen, factory shipping |
| 400 | 916 | suburbs (140 bedrooms, 98 kitchens), a medical cluster (12 medical, 11 medical offices, 7 clinics, a hospital hallway, 3 pharmacies, a lab), the Herald office, **a military camp at the rail yard** (24 army tents, army storage, train cars) |
| 700 | 2,213 | the edge of Louisville proper |

Compared with the downtown studios (2,000+ rooms within 300) it's quiet at the door,
with the city's supplies a walk away — and the rail-yard camp (about 12690–12715,
4380–4400, two control rooms, 220 tiles east) is a ready-made story: the quarantine
camp that fell.

The user checked the building on the map site: it works. Still to pin down in game:
the exact entrance square for the crate, the desk/mic squares, where the transmitter
and generator go, and how many zombies the map puts there (we can thin the area at
the start).

Runner-up if the user's scratched pick was something else: **the transmitter site at
4827–4838, 6277–6286** (a control room, office, bedroom, bathroom, storage, a garage,
a real radio mast in the cell). Nothing within 300 tiles, but within 600 a village of
about 40 houses with two electronics stores (repair parts), a gas station, a diner, a
general store and a mechanic.

Rejected: the downtown Louisville studios (too dense), the race track press box at
879, 13037 (cell 3_50 is a racetrack: the "broadcasting" room is the commentary box),
the mast at ~2650, 10880 (a gun range/laser tag/army surplus complex, no station
building), the control rooms at 7166, 12566 (an electronics store alone in the
country) and 12697, 4386 (the rail yard's).

## Radio test results (2026-10-28, played)

Both worked: a five-line show aired on **LBMW's own 93.2** (vanilla's channel, found
with `register = false`; the radio shows "LBMW - Kentucky Radio") and on our **96.4**
("Vitality Challenges"). Every radio switched on in the loaded area picked it up (three
house radios at once), so the station really is heard around you.

- **Pacing:** the radio shows a line about every 3.5–5 real seconds at normal speed
  (about 1.2 game minutes; longer lines take longer). A 5-line show took about 19 s, or
  5 game minutes. A 20-line show is about 20 game minutes on air.
- **Speech:** saying the host's lines on a fixed 4-second timer ran ahead of the radio
  (line 4 was said before the radio reached line 3). The real build says each line as
  the broadcast reaches it (paced by the game, not a timer).
- **Decision: air on LBMW 93.2.** "LBMW is back on the air", on the vanilla station
  Jackie Jaye reported for. 96.4 stays as the spare (the callers' frequency, or a
  later challenge).

## Pillars

1. **The appointment.** Broadcasts happen at set times. Being at the mic, with power
   and a working transmitter, at 18:00 is the spine of every day. Missing one hurts.
2. **The audience is real (inside the game).** Your broadcast is a real radio channel:
   tune any radio in the world to your frequency and you hear what you said. Listeners
   call in on a second frequency with names, stories and requests that run over days.
3. **The signal is a beacon.** Power, noise and lights at night draw the dead. The
   longer you stay on air, the more the station becomes the loudest thing in Kentucky.
4. **The station breaks.** The transmitter wears, the antenna takes storms, the
   generator drinks fuel. Keeping it running is Electrical, scavenging and climbing
   onto a roof in the rain.
5. **The world pays you back.** Listeners leave supplies at dead drops, warn you of
   hordes, tell you where the pharmacy still has stock. Good radio buys survival.
6. **Vanilla first.** Everything works without Vitality. With Vitality, the conditions
   layer in (Sensory Issues and the noise, Insomnia and the night shift, Burnout from
   defending the station, medication requests from callers).

## Where

Real broadcast rooms found in the B42 map data (room names in the lotheaders;
coordinates are world x,y, floor). **[decide]** which building; I'd check each on the
map site before choosing.

| Site | Where | Floors | Notes |
|---|---|---|---|
| A. Louisville broadcast complex | ~13040–13085, 1410–1540 | studios floor 1–3, broadcasting floor 2 and 4 | big, multi-floor, next to the Top of the World tower. Louisville crowds. |
| B. Louisville studio with "Joan's studio" | ~12630–12660, 1883–1940 | 0–1 | a TV studio (named presenter room), storage downstairs |
| C. Louisville studio | ~12334–12370, 2040–2075 | 0–1 | two broadcasting rooms, storage |
| D. Studios high in a tower | ~12709–12735, 1605 | 6–7 | broadcasting on floor 7 of an office tower |
| E. Small-town station? | ~879, 13037 | broadcasting room on floor 3 | far south-west; same building has many kitchens (apartments above shops?) — needs a look |
| F. Rural radio masts | cells 10_42 (~2560–2816, 10752–11008), 18_24 (~4608–4864, 6144–6400), 14_57 (~3584–3840, 14592–14848) | — | radio tower sprites (95 tiles in two of them: real masts). Maybe a transmitter shed at the foot. |

My lean: **a rural mast with a small station building (F) or the small-town station (E)**
for the main challenge — survivable, readable, feels like the "last guy keeping the
lights on" fantasy — and a later **"Louisville" hard variant** at A, where the crowd is
the challenge.

## The core loop

```
morning   sleep off the night shift · check fuel · walk the antenna
day       scavenge: fuel, parts, food, whatever a caller asked for · reinforce
evening   prepare the broadcast (pick segments) · power up · 18:00 ON AIR
night     the station hums and glows · the dead come to the noise · defend · callers reply
```

### Going on air

The station has a **studio desk** (a placed vanilla `Mov_Microphone` / ham radio
tile on the desk) and a **transmitter** (an object we mark in the transmitter room;
see "Station objects"). To broadcast:

1. Power: the transmitter's square has electricity (a generator in range, as vanilla
   decides; the grid is off from day 1). **[decide]** grid shut-off day.
2. The transmitter's condition is above 0, and the antenna is up.
3. You stand at the desk in the slot's window (default 18:00–19:00, the window is an
   hour) and use **Go on air**: a timed action of about 15 game minutes, interruptible.
   Your character talks (we can play vanilla's shout/talk lines lightly, or none).
4. What you broadcast is what you put in the **running order** (below). The lines go
   out on your channel as real `RadioLine`s, so anyone (you, with a walkie on the roof)
   hears them.

**[decide]** one slot a day (18:00), or two (08:00 and 20:00), or player-chosen once
and then fixed ("you told them 7pm, so it's 7pm").

### The running order (what you say)

Before going on air you pick 2–4 segments at the desk (a small window, our own UI).
Each segment needs something; each adds listeners and/or does something.

| Segment | Needs | Does |
|---|---|---|
| **Station ID + time** | nothing | baseline; on time is what counts |
| **Weather** | a working radio to hear the AEBS, or a barometer/thermometer item, or Meteorology isn't a skill so: a forecast you noted at the window | uses the game's real forecast (`WeatherChannel` code already builds sentences). Accurate warnings = listeners. |
| **Places** | locations you have visited since the last show (we track "scouted" building types and towns) | "The Fallas Lake pharmacy still has stock." Listeners value fresh, real places. Draws callers to places. |
| **Safety tips** | First Aid / Cooking / Farming level ≥ some value, or a skill book/magazine you have read | a topical tip; with Vitality, medical tips from First Aid tiers |
| **Music** | a CD/vinyl and a CD player or record player wired in | listeners love it; costs fuel time; no info |
| **Answer a caller** | an open caller request | closes or advances that caller's thread |
| **Read a message** | a note found in the world (we place letters/notes on the map) | story; some notes are from callers' families |

The text is assembled from translation-key fragments with the real values filled in
(town names, the forecast, a caller's name), so every show is different and true to
the save. You can tune a radio to your own frequency and hear it, which is half the
charm.

### Listeners

A hidden-ish number shown on a station board in the studio (and in the summary).

- On-time show: +; a missed slot: a bigger −; two missed in a row: callers stop.
- Variety (not the same running order three nights in a row) and truth (a weather
  warning that came true, a place that really had what you said) add more.
- Listeners unlock things: more callers, dead drops, warnings, the ending.
- They never directly hurt you; they are the score.

## The audience talks back: callers

A second channel (`Amateur`, a fixed frequency told to you by the first caller) where
callers speak **after** your show and at random hours. Each caller is a short **thread**
with 3–6 beats over days. Threads are data (a table of beats with conditions), so
writing more is cheap, and they're the real content of the mode.

Example threads (sketches):

- **Marjorie, 71, alone in Rosewood** — just wants to hear a voice. Asks you to play
  something on her late husband's birthday (a music segment that night). If you do,
  her nephew leaves her husband's tools in the crate, with a note (with Vitality:
  meds for one of your conditions too). If you miss three shows, her calls stop.
- **The Ekron kids** — two teenagers holed up in a school. They ask how to purify
  water (a safety tip with Cooking or the right magazine). Later they ask you where a
  pharmacy is (a Places segment naming one you've visited). Later still: silence, or a
  thank-you and a cache.
- **Sergeant Hollis** — a soldier on the Muldraugh line. Gives horde warnings ("a big
  group moving north up the 31W") — a real horde we spawn and send toward the station
  a day later. If you broadcast the warning, listeners rise; either way you'd better
  prepare.
- **The Preacher** — a calm voice on a different frequency who doesn't like your
  station. Later threads hint that raiders are listening too (with the Bandits mod: real
  raiders; vanilla: a burglar-style break-in event at a dead drop).
- **Dr. Ames (with Vitality)** — asks about a condition; answering with a First Aid
  tier tip earns medical supplies.

Callers can **ask for something back** ("my boy needs insulin, if you have a spare,
leave it in the crate tonight"): put it in the crate before dark and it's gone in the
morning. Giving costs you; rewards come later and bigger, and the thread remembers.

**Beats react to the world.** Each beat has conditions on the real state: the weather
now and the forecast (a caller trapped by the flood after three days of rain; a
blizzard night when nobody calls, then everyone does), the season and temperature,
the day count, the power (the grid going off is a shared event every caller talks
about), whether you aired what they asked, what's in the base, the listeners. A
thread can branch, wait, or end badly. The narrative is a pool of threads with
triggers, not a fixed script, so two runs tell different stories.

**[decide]** how many threads at launch (my lean: 8 with 3–6 beats each).

## The donation crate (replaces far-off dead drops)

A crate placed at the station's entrance (a vanilla crate tile, our own container
type or a marked vanilla one). Listeners leave things in it **overnight after a
show**: people come in the dark, when it's safest. You find it in the morning.

**How often and how much:** driven by listeners. A small station gets a can of beans
every few nights; a big one gets a gas can and a box of shells most mornings. A missed
show means nobody comes that night.

**What turns up: what you're short of.** Once a day, before the drop, we take stock of
the base: every container inside the station building (and anything within a few tiles
of it, so a shed or the generator counts):

| Need | Measured by | Gives |
|---|---|---|
| Fuel | units in gas cans + the generator's tank, in days of running | gas can (part full) |
| Food | calories stored, in days (the Nomad maths: ~2,800/day) | tins, dry goods, sometimes fresh |
| Water | water units in bottles/pots, in days | bottled water, a filled jug |
| Weapons | count and condition of melee weapons | a used weapon (a bat, a crowbar, a machete when big) |
| Ammo / guns | rounds per gun held | a box of the right calibre; rarely a gun |
| Medical | bandages, disinfectant, pills | a few of each; with Vitality, your medication |
| Parts | ElectronicsScrap, wire, the transmitter's condition | scrap, wire, now and then an amplifier |
| Comfort | books/magazines/CDs | a magazine, a CD to play on air |

Each need gets a weight from how low it is (out = heavy, plenty = near zero) and the
night's donations are rolled from those weights. So the game quietly answers "I'm out
of gas" without making it free: the amount is small, and it only comes if you kept the
show going. Listeners asked for on air ("we're low on fuel") weight it further — a
**Requests** segment for the running order, with a cost: say it too often and listeners
drop ("all he does is beg").

**Notes in the crate.** Some drops come with a note from a caller ("for the show —
Marjorie"), which ties donations to the caller threads. A thread can promise a
specific drop ("my brother will bring you his generator fuel on Friday") and the
crate keeps the promise — or doesn't, if something happened to him (which you hear on
the radio).

**Trouble at the door.** Now and then the morning crate has a dead donor beside it
(a zombie in civilian clothes with a backpack holding the donation), or the crate is
torn open (zombies drawn by the noise trampled it — half the drop is scattered). With
the Bandits mod: raiders who heard where the drops go.

**In MP / with Base Unloader:** later. In vanilla the "base" is just the station
building plus a radius, which needs nothing else.

## The signal is a beacon (threat)

- **On air:** while transmitting, a world sound pulse at the station every few minutes
  (`addSound`, radius rising with listeners — fame is noise). **[decide]** radius curve.
- **Generator:** vanilla's own generator noise already draws zombies. Keep it.
- **Lights:** the studio's ON AIR light is a light at night (vanilla lights draw nothing
  much; maybe we add a small pull).
- **Escalation:** every 5 days on air, a migration aimed at the station (vanilla meta
  events can't be aimed, so we spawn a group at the edge of loaded cells and give them
  a sound to walk to). Size grows with days; capped low enough not to crash (lesson
  from Nomad: be conservative).
- **Storms:** a thunderstorm damages the antenna (chance per storm hour); a blizzard
  ices it.

## The station breaks (maintenance)

- **Transmitter condition** 0–100. Drops a little each broadcast, more when the power
  dips (generator out of fuel mid-show = a hit). Repair at the transmitter with
  Electrical level and parts: `ElectronicsScrap`, `ElectricWire`, `Amplifier`,
  `RadioTransmitter`, `RadioReceiver` (all vanilla items, salvaged from radios, TVs,
  walkies). Higher Electrical = less parts per point.
- **Antenna**: up or down. Fixing needs a ladder/roof access, `ElectricWire`, scrap
  metal, Metalworking or Electrical. Climbing in a storm: a fall chance (and with
  Vitality, Brittle bones / concussion hooks).
- **Fuel**: a 30-day run needs a lot of gas; the generator at the start has a few days.
  Siphoning and gas stations are the day trips.
- **The station's own log** (an in-world notebook item at the desk): the previous
  engineer's notes that teach the systems ("the antenna feed corrodes in the rain —
  check it after storms"), then your own entries appended automatically (shows,
  callers, drops). This doubles as the tutorial and the journal.

## Start

- **When:** **[decide]** day 1 (the panic, power still on for a while, AEBS still
  running) or a week in (power just gone, AEBS fading). My lean: day 3, grid off on day 5
  — a couple of shows with mains power to learn, then the generator becomes real.
- **Who:** any profession; Electrician/Engineer/Radio Operator-ish professions get a
  head start (Electrical levels). Kit: the station keys, a flashlight, a walkie-talkie,
  a notebook and pencil, some food from the staff room, a fire axe from the wall.
- **The station:** doors locked, one generator in the back with a few days of fuel, a
  gas can, the transmitter at 70%, the antenna up, the studio stocked with a few CDs.
- **Settings:** **[decide]** normal Apocalypse-ish zombies with the beacon making it
  harder over time, or harsher from the start. One life? (Nomad is one life; I'd make
  this one life too — "the last broadcast" if you die.)

## Winning and losing

- **Win:** 30 shows aired (a day counts if the slot was met). **[decide]** strict 30
  consecutive days, or 30 shows by day 40 (slack for a bad week).
- **The final broadcast:** on day 30 a special running order unlocks: you can read a
  sign-off, name your callers, play a last song. The callers who are still alive call
  in. Then the summary (days, shows, missed, listeners peak, callers saved, drops
  found, kills, fuel burned) and the record line, and you keep playing — the station is
  yours.
- **Lose:** death (one life). **[decide]** also a loss if listeners hit zero (I'd say
  no: the score falls, the run goes on).

## Optional layers

- **Vitality:** callers ask for medical tips by First Aid tier; Sensory Issues makes
  the on-air hour a quiet relief or the generator a misery; Insomnia makes the night
  shift easier; Burnout from defending, and a show counts as a comfort (talking to
  someone). Medication can be a caller trade.
- **Bandits mod:** raiders who listen — the Preacher thread turns into a real attack.
- **Project A-Life:** survivor NPCs who arrive at the station because they heard you
  (big, later).
- **MP:** co-op station (one on the mic, one on the roof). Not for v1.

## How it's built (on the frame)

New pieces for `VitalityChallenges`:

| Piece | What | Size |
|---|---|---|
| `VC.radio` | registers our two channels via `DynamicRadio.channels` (fixed uuids, `Radio` and `Amateur` categories) and queues broadcasts: `channel:setAiringBroadcast(bc)` with `RadioBroadcast` + `RadioLine`s (the way `ISWeatherChannel` does it). Must be in `server/` like the vanilla file. | small, needs an in-game spike first |
| Station objects | find the transmitter/desk squares at the start (fixed coords per site) and keep their state in world ModData (condition, antenna, last show). Context-menu options on those squares: Go on air, Running order, Repair, Check antenna. | medium |
| Running order window | a small ISPanel: segment checkboxes greyed with the reason; text preview. | medium |
| Show assembler | builds lines from segment templates + live data (forecast via `getClimateManager()` forecasts, scouted places, caller state). | medium; this is where the polish goes |
| Callers | a thread table, a scheduler (after the show, random hours), beat conditions/effects. | medium; content is the big part |
| Dead drops | building lookup by room type near the station, lazy spawn on chunk load (`LoadGridsquare`), container fill. | medium |
| Beacon | sound pulses on air; escalation groups with a walk-to sound. | small–medium |
| Maintenance | condition, repair action with parts and Electrical, antenna, storm damage. | medium |
| Goal: shows | a `shows` goal type in Rules (count, deadline) with the final-show unlock. | small |
| Log notebook | an item with its text written from events (vanilla notebooks hold pages). | small |

Phases:

1. **Spike** (an hour of play): register a channel, air one broadcast, hear it on a
   radio. Confirm the server-folder registration and that lines show in the radio's
   text. Without this nothing else matters.
2. **The appointment:** site, start, Go on air, running order with 3 segments (ID,
   weather, places), listeners, the 30-show goal, the beacon pulse. Playable.
3. **Callers + dead drops:** 4 threads first, then more.
4. **Breakage:** transmitter, antenna, storms, the log.
5. **Final broadcast, summary, polish, Vitality/Bandits layers.**

## Open decisions

Settled: never far from the station; one show at 18:00; the donation crate at the
entrance, leaning to what you're short of; callers fully scripted, reacting to the
world.

1. ~~Site~~: Jackie Jaye's studio, south Louisville. ~~Start date~~: day 14.
2. Where you start: the fallen rail-yard camp 220 tiles east (my lean: a short first
   act with a reason to go), inside the studio, or Riverside (a trek across the map)?
   When must the first show air (e.g. the first evening at 18:00, or day 15)?
3. The power on day 14: still on for a few days (learn the station on mains, then
   the generator becomes real), or already off?
4. Win: 30 consecutive shows, or 30 within 40 days? And does the clock start at the
   first show?
5. One life?
6. Beacon: how hard should fame bite? (pulse radius, escalation size)
7. Callers at launch: how many threads? Any you want to write yourself?
8. Does the player's character speak on air (overhead text lines) or only the radio?
9. Donation size: how generous at peak listeners?

## Later: start in Rosewood (decided 2026-10-29, not built)

The release start moves far outside Louisville, to Rosewood, so reaching the
studio is a real journey. The lakeside house start (12240, 3683) stays while the
core loop is tested. Decisions:

- Start: the house at 8135, 12044 (map-site coordinates; check against the
  lotheader room data when building, as the site was ~20 tiles off for the lake
  house).
- First-show deadline: none. The two-day gap clock starts with the first show the
  player airs; until then no evening counts as missed. (Replaces MISSED_START, the
  one extra evening for the walk.)
- Cars: driving allowed.
- Map: unchanged, south Louisville with the studio circled; the route is the
  player's to find.

## Test mode (on)

`TEST = true` at the top of VitalityChallenges_LastBroadcast.lua, for play-testing the core loop: the Low zombie population, one dead in the studio and none in the street, and the studio's containers stocked with a bit of everything (food, water, medical, two full gas cans, batteries, tools, melee and guns with ammo, bags). A step van also spawns at 12287, 3803 (repaired, full tank, the same stock in the back, its key in your inventory). Set it to false before release; the test suite prints a note while it is on.
