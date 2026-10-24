# The companion app

A browser app that runs beside the game and talks to the mods through files in
`~/Zomboid/Lua/`. It grows out of `DanTraits/tools/dashboard.py` (the live readout
and command console used for testing) and becomes the home for everything that
needs the outside world: PZ Chronicle's Claude call, the Spotify bridge, long
history, logs. It is personal tooling, not a Workshop item, and it never ships in
the mod upload.

Written 2026-10-13 from the design talk. Status at the bottom.

## Where it lives

Its own repo, `../pz-companion`, beside `pz-dans-traits` and `pz-chronicle`.

- It spans three mods (Vitality Project, Chronicle, the music module), so it
  belongs to none of their folders.
- It will hold a Claude API key and a Spotify client id. Those live in the
  user's profile (`~/.pz-companion/config.json`), never in a mod folder and
  never in a repo. The repo's `.gitignore` keeps them out even if copied in.
- Its release cadence is "whenever"; the Workshop has a real one.

The dashboard moves across whole, with its page split out of the Python string
into static files. `DanTraits/tools` keeps `make_icons.py` only.

## Architecture

One Python process, standard library plus the official `anthropic` package for
the Claude call (the API guidance is to use the SDK, not raw HTTP; Spotify's
API is plain `urllib`). It serves `http://127.0.0.1:8642`,
polls files in `~/Zomboid/Lua/`, and writes replies back there.

```
game (Lua, no network)          ~/Zomboid/Lua/                companion.py (:8642)
DanTraits_Telemetry.lua  -->  DanTraits_Telemetry.json  -->  Live tab, history db
                         <--  DanTraits_Commands.txt    <--  command panel (debug only)
ChronicleMain.lua        -->  chronicle_export.json     -->  Chronicle tab -> Claude
                         <--  chronicle_entries.txt     <--  diary entries
PZCompanionMusic.lua     -->  music_state.txt           -->  Music tab -> Spotify
                         <--  music_now.txt             <--  now playing
every mod                <--  companion_link.txt        <--  heartbeat, every 5 s
```

The companion's own state (config, history, story archive, tokens) lives in
`~/.pz-companion/`, not in `Zomboid/Lua/`, which the game owns.

### The link heartbeat and the debug gate

Telemetry today only writes in debug mode, and the command channel shares the
gate. For a companion used in ordinary play the two split:

- The companion writes `companion_link.txt` every 5 s containing the unix time.
  The mod reads it every 10 s (`getFileReader`) and treats the link as alive
  while the stamp is under 60 s old (`getTimestamp()` is seconds since epoch).
- Telemetry writes when the game is in debug mode **or** the link is alive.
  Users without the companion pay nothing: one small file read every 10 s.
- The command channel (give, set health, run Lua) stays debug-only. The Live
  tab hides the command panel unless the telemetry says `debug: true`.
- Multiplayer stays off for both, as now.

File names that another mod might target are mod-neutral (`companion_link.txt`,
`music_*`, the LLM queue below), the way `OnStoryEvent` was.

### One LLM queue for every mod

Chronicle is the first customer and the A-Life minds plan is the second, so the
Claude call is a generic service, not a Chronicle feature:

- A mod appends a JSON line to `llm_<mod>_requests.jsonl`:
  `{"id": "...", "system": "...", "prompt": "...", "maxTokens": 600}`.
- The companion tails each `llm_*_requests.jsonl` it finds, calls the API, and
  appends `{"id": "...", "text": "...", "error": null}` to `llm_<mod>_replies.jsonl`.
- The mod reads replies, matches by id, and truncates the file it consumed.
  The companion keeps its own read offsets in `~/.pz-companion/`.

Chronicle keeps its export/entries pair for now (it carries more than a prompt:
the profile, the pending days, the acknowledgement). The companion's Chronicle
module builds the prompt from that export and calls the same client the queue
uses. When A-Life minds arrives it uses the queue directly.

Model: a Claude 5 family model chosen in Settings, `claude-opus-5-5` by
default (the current default model; Sonnet 5.5 and Haiku 5.5 are the cheaper
choices in the list). Effort `medium`. Server-side fallbacks are on, so a
policy decline is re-run on a fallback model inside the same call; a 400 on the
parameter turns it off for the session.

## Tabs

- **Live.** The dashboard as it is: vitals, mod-data cards grouped by prefix,
  stat attribution, the story card, sparklines. The command panel appears only
  when the game reports debug mode.
- **Chronicle.** Pending days waiting for an entry, the archive per character
  with the rolling summary, a rewrite button, voice settings (terse while
  depressed, rambling while drunk, age band), and the diary export. Replaces
  the Express server named in Chronicle's README, which was never built.
- **Music.** Spotify sign-in (authorization code with PKCE; the redirect lands on
  the companion's own port), device pick, now playing, and the mood-to-playlist
  map the music module will drive. Needs Premium and a personal Spotify dev app
  the user creates. Mod side unbuilt; the first step is the Walkman spike that
  pauses and resumes playback.
- **Console.** The last lines of `~/Zomboid/console.txt` filtered to the mods'
  prefixes, errors highlighted. The Lua debugger freezes the game on any error
  (Break On Error), so the error text being readable outside the game matters.
- **History.** Week-long charts from a SQLite log of telemetry samples (glucose,
  weight, vitality, sleep debt, blood). One sample a minute is plenty; the
  in-page sparklines keep their ten minutes at two a second.
- **Ledger.** Every character Chronicle has seen: name, days survived, kills,
  cause of death, their diary. Source for the dead-character's-diary-as-loot idea.
- **Guide.** `docs/field-guide.html` from the pz-dans-traits checkout, served as is.
- **Settings.** Paths (Zomboid folder, the pz-dans-traits checkout for the
  guide), API key and Spotify credentials, model choice, LAN binding.

Screenshots: the game drops them in `~/Zomboid/Screenshots` with timestamps.
The Chronicle tab matches them to the day and shows them beside the entry.

Phone access: `--lan` binds to the machine's LAN address instead of loopback so
the diary and now-playing read on a phone. The command route refuses non-local
clients even then.

Deferred: desktop notifications, a sandbox options editor, a tray icon,
text-to-speech diary reading, a Claude radio DJ.

## Build order

1. **Move and shell.** New repo, the dashboard's page split into static files,
   tab layout, the heartbeat writer, the link gate in `DanTraits_Telemetry.lua`,
   Console and Guide tabs (both trivial), stubs for the rest. The old
   `Dashboard.bat` goes; the README and `tests/run_tests.py` stop pointing at it.
2. **Chronicle bridge.** The LLM client, the export watcher, prompt builder,
   rolling summary, entries writer, the Chronicle tab. Then the diary item
   write-back on the mod side (Chronicle phase 3).
3. **History and Ledger.** The SQLite log and the two tabs.
4. **Music spike.** Spotify sign-in and pause/resume from a Walkman toggle in a
   new `DanTraits_Music.lua` (or its own small mod). Then the design in
   `plans/backlog.md` (stereo, moods, noise, sleep fade).
5. **Checklist and screenshots.**

## Decisions

- Build on `dashboard.py`, don't start over (2026-10-13).
- Own repo, standard library plus the `anthropic` SDK, secrets in the user profile.
- Telemetry on whenever the companion is running; commands debug-only.
- Mod-neutral file names for anything another mod might use.

## Open

- Does `getFileReader` on a missing file return nil or raise in B42? The
  telemetry code already wraps it in `pcall`, so the gate does the same.
- Spotify: the dev app, Premium, and which account. User's side.
- ~~Whether the music module is a file in Vitality or its own mod.~~ Its own mod,
  `PZCompanionMusic`, kept in the companion repo (2026-10-14).

## Chronicle bridge, as built (2026-10-14)

- `chronicle.py`: a watcher thread polls the export every 3 s; a new export
  writes every pending day without an entry, oldest first, one call each. The
  prompt: a system block (voice rules, profile, the rolling summary, the previous
  entry, cached) and the day rendered as text with kills grouped by weapon and
  place, skill lines folded, the rest in order, capped at 120 lines. The model
  returns JSON (`title`, `entry`, `summary`) through `output_config.format`.
- The archive per character is `~/.pz-companion/chronicle/<id>.json` with the
  day's record kept beside each entry, so a rewrite needs no game.
- `chronicle_entries.txt` carries every entry whose date the game still lists
  as pending; the mod acknowledges by date. A failed day is not retried until
  the next export or a manual write.
- Mod side (`ChronicleMain.lua`): a second day on one date gets a `-2` suffix
  (the date is the key, so two naps on one date used to collide); received
  entries go onto the Survivor's Diary's pages (`getCustomPages`, `addPage`,
  1400 characters a page, the date as a heading) and the diary takes the
  character's name. Compiles under fengari; not played.
- Not done: screenshots beside entries (step 5), the generic LLM queue (when
  A-Life minds needs it), a real API call (no key on this machine yet).

## Music spike, as built (2026-10-14)

- B42 has no Walkman; the CD player (`Base.CDplayer`, a portable battery radio)
  is the remote. Any CD player switched on anywhere in the inventory, bags
  included, with charge in its battery counts as on.
- Mod: `pz-companion/mods/PZCompanionMusic` (id `PZCompanionMusic`), deployed by
  `deploy_mods.py`. It writes `music_state.txt` (time, on, volume, paused,
  device, cmdSeq, cmd) on change and every 5 s, only while the companion's
  heartbeat is fresh; it runs on `OnTickEvenPaused` so a pause is reported.
  Right-click on a CD player that is on: next, previous. A new track shows as a
  halo note while the CD player is on.
- Companion: `music.py`. PKCE sign-in, redirect
  `http://127.0.0.1:<port>/spotify/callback` (Spotify refuses `localhost`).
  Edge-triggered: on presses play (resume, or the chosen device and playlist
  when nothing is loaded), off or a game pause presses pause, a stale state file
  (game gone) pauses only music the companion started. The volume knob is sent
  on change, at most once a second, never at switch-on. Tokens in
  `~/.pz-companion/spotify_tokens.json`.
- Spotify's February 2026 rules: the app owner needs Premium, 5 users per
  development app; the player endpoints are unchanged.
- Tested offline (`tests/test_music.py`, a fake Spotify) and the mod under
  fengari with stubs; no real Spotify call yet (needs the user's app and
  sign-in), not played.
- Radios (2026-10-14, same day): Spotify has its own station, **104.6 MHz**,
  registered as a DynamicRadio channel ("Spotify 104.6", uuid
  `PZCM-SPOTIFY-1046`, server/PZCompanionMusic_Station.lua), clear of every
  vanilla frequency. A source plays Spotify when on with power and either has
  no tuner (`isNoTransmit()`: the CD player) or is tuned to 104.6: inventory
  radios, the car radio (`getVehicle():getPartById("Radio")`), and placed
  `IsoWaveSignal`s scanned one floor a second within 22 tiles. Placed radios:
  radius = base volume range x 1.5, volume x (1 - (d/r)^2), another building or
  inside/outside x 0.35 and silent past 6 tiles, x 0.5 per floor, 5% steps. The
  loudest source wins. Every tuner met gets a "Spotify 104.6" preset; right-click
  offers "Tune to Spotify 104.6". New tracks air as a broadcast line on the
  station (`RadioBroadCast`/`RadioLine`, `setAiringBroadcast`); the CD player
  keeps the halo. The state file gained source, scaled and station; a placed
  radio's faded volume is sent with the play. Broadcast lines also make the
  radio audible to zombies the vanilla way. The random emergency broadcast can
  land on 104.6 (1 in 100 worlds): logged, not moved.
- Out of earshot, cars, muffle (2026-10-14, user asked): a placed radio found
  playing stays tracked while its square is loaded (`getCell():getGridSquare`
  returns the same square and it still holds the object): out of earshot it
  reports on at volume 0, so Spotify keeps playing silently; unloaded, picked up,
  switched off or retuned drops it. Wall radius is now 0.4 of the range (was a
  6-tile cut). Car radios come from `getCell():getVehicles()`: the one the player
  sits in at full, the rest heard from outside through the shell (x 0.45).
  Each source reports `muffle` 0..1 (wall 0.6, floor 0.25 each, car shell 0.5,
  distance up to 0.3). The companion sets a placed radio's volume before the
  play. Muffle is shown in the tab but not yet audible: Spotify's Web API only
  has volume, so a real low-pass filter needs the audio to pass through
  something the companion controls.
- Muffling built (2026-10-14, user picked Equalizer APO over librespot):
  `muffle.py`. Spotify -> CABLE Input (Windows volume mixer, per app);
  Equalizer APO 1.4.2 installed on CABLE Input only; CABLE Output "Listen to
  this device" -> speakers. The companion writes `pzcompanion.txt` in APO's
  config folder (path from HKLM\SOFTWARE\EqualizerAPO ConfigPath) and appends
  `Include: pzcompanion.txt` to config.txt once (backup kept). APO reloads
  files in its config folder on change. Muffle rounded to tenths, low-pass
  20 kHz -> 300 Hz on a log scale, doubled (24 dB/oct) from 0.5, rewritten at
  most once a second; cleared when the game is not playing Spotify (paused,
  off, gone) and when the companion stops (finally + a Windows console close
  handler). If the folder is locked, the tab shows four admin PowerShell lines
  that grant the user modify rights on that one file. Music tab card: the
  walkthrough, a VB-CABLE check (Get-PnpDevice), buttons opening the volume
  mixer and Recording devices, test buttons (6 s at 0.3 / 0.7 / 1). Not tried
  with the real tools: neither is installed on this machine yet.
- Volume speed (2026-10-15, user: "the 5 second volume checks are too slow"):
  the companion's log showed sends within a second of each game change, so
  the lag was Spotify's Web API reaching the desktop app. Volume now goes to
  Spotify's session in the Windows mixer (`winvol.py`: IMMDeviceEnumerator ->
  every active render device -> IAudioSessionManager2 sessions -> process
  Spotify.exe -> ISimpleAudioVolume; about 2 ms a set), sent up to ten times a
  second; Spotify's own volume goes to a base (100) once per play, and the
  slider is restored on pause/stop/exit. The game re-checks every 0.25 s
  (was 0.5), the companion polls every 0.25 s. The volume now follows the
  game at switch-on and on every source change too (it used to keep Spotify's
  level for a held radio, which left the car at 45% after getting back in).
  Spotify's player endpoints sometimes answer 200 with a non-JSON body: no
  longer an error.
- Now-playing display (2026-10-15): `PZCompanionMusic_Panel.lua`, an ISPanel
  (station + device, song in Medium, artist, progress bar, times; "paused";
  "outside the car" / "out of earshot"), shown while a source plays and the
  companion has said what is on; position kept in
  `Lua/PZCompanionMusic_panel.txt`; right-click hides it, "Show/Hide now
  playing" on a playing radio's menu. `music_now.txt` gained album, uri,
  progress, duration and `at` (unix ms); the companion rewrites it on a seek
  (drift over 1.5 s), polls Spotify every 3 s and again 0.7 s after the song
  should end. The game announces a song only when its uri changes (a seek or a
  pause no longer re-announces); the halo is skipped while the panel shows. A
  CD player/boom box without a disc shows "Spotify: song - artist" on the
  RWMMedia LCD: vanilla's per-frame setText/setDoScroll are held back while
  the song owns the display, or the scroll would restart every frame.
  Album art not attempted (loading a changing image at runtime is unproven).
- Next: the backlog design (mood playlists, sleep fade, now playing in
  Chronicle), and the 90s radio filters on the Equalizer APO chain once the
  user has it set up.

## Status

- 2026-10-13: plan written. Step 1 built: `../pz-companion` (companion.py, static/, Companion.bat,
  README), Live/Console/Guide/Settings working, the other tabs stubbed; the link gate and `debug`
  flag in `DanTraits_Telemetry.lua` with tests (77/77); old dashboard removed from this repo;
  deployed, not yet played. Neither repo committed.
- 2026-10-14: step 2 built (Chronicle bridge, Ledger tab, Chronicle phase 3 in the mod); offline
  test green on the real export; no API key on the machine, so no real entry written yet.
- 2026-10-14: step 4 spike built (Music tab, music.py, the PZCompanionMusic mod), then radios and
  the 104.6 station; offline tests green; waiting on the user's Spotify app and a play test.
