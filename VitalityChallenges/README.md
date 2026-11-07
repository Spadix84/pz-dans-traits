# Vitality Challenges

Challenge scenarios for the game's Challenges menu. Part of the
[Vitality Project](../README.md) repository; each runs on its own, and with the Vitality
Project loaded its systems join in. Not yet on the Workshop.

- **Pile-Up.** You fled Muldraugh on the first night and drove into the back of a traffic jam
  on the highway in a thunderstorm. Your leg is broken, the car is dead, whatever you packed
  is in the trunk. No win condition. With the Vitality Project the crash also concusses you.
- **Nomad.** A year on, in a December blizzard at the far south-west edge of the map, walk to
  the top floor of the Louisville tower. No car starts, one life, a big bag, a tent, three
  days of food, a map with the tower circled, weapons by profession. With the Vitality
  Project you start with your medication.
- **The Last Broadcast.** Two weeks in, the radio has gone quiet. Clear the LBMW reporter's
  studio in south Louisville and put the station back on the air at six every evening:
  thirty shows, never more than two days apart, as the listeners grow. Design in
  [plans/last-broadcast.md](../plans/last-broadcast.md).

| Layout | |
|---|---|
| `42/media/lua/client/VitalityChallenges_Core.lua`, `_Rules.lua`, `_Kit.lua`, `_Scene.lua` | the frame: registering a challenge, its rules, starting kit and scene |
| `42/media/lua/client/VitalityChallenges_PileUp.lua`, `_Nomad.lua`, `_LastBroadcast.lua`, `_Broadcast.lua`, `_OnAir.lua` | the three challenges |
| `42/media/lua/server/VitalityChallenges_Radio.lua` | the LBMW station's shows |
| `42/media/lua/client/VitalityChallenges_Dev.lua` | play-test scaffolding behind its TEST switch (off for release) |
| `42/media/lua/client/VitalityChallenges_Guide.lua` | its page in the Vitality Project's Guide tab (does nothing without it) |
| `../tests/test_challenges.lua`, `test_nomad.lua`, `test_lastbroadcast.lua` | offline tests |
| `CHANGELOG.md` | its own changelog |

Deploy with `python deploy.py --mod VitalityChallenges`. Singleplayer.
