# Historical Weather

A Project Zomboid (Build 42) mod, in development: Knox County's real weather from
9 July 1993 (the game's start date) to 9 July 1995, from NOAA's daily record for the
Barbourville, KY co-op station (USC00150381, in the real Knox County). Before and after those
two years the game's own weather runs as usual.

| Layout | |
|---|---|
| `data/knoxCountyHistoricalWeatherData.pdf` | the source: NCEI's "Record of Climatological Observations", 32 monthly pages |
| `data/daily.csv` | the record moved onto the right days, in C and inches, gaps filled where short (see below); hand edits here, then `build_data.py --csv` |
| `tools/build_data.py` | PDF -> `daily.csv` -> `HistoricalWeather_Data.lua` (needs `pip install pypdf`) |
| `42/media/lua/shared/HistoricalWeather_Data.lua` | generated: one row a day, `{ high, low, rain start, rain hours, rain intensity, snow, thunder }` |
| `42/media/lua/shared/HistoricalWeather.lua` | the hour's weather from the day's row, and putting it into the game's climate |

    python -I HistoricalWeather/tools/build_data.py         rebuild everything from the PDF
    python -I HistoricalWeather/tools/build_data.py --csv   rebuild the Lua from daily.csv
    python deploy.py --mod HistoricalWeather
    python deploy.py --workshop HistoricalWeather           the upload folder (no tools/ or data/)
    python workshop/weather/make_images.py                  the Workshop pictures, from the mod's own output

In game, `print(HistoricalWeather.report())` in the debug console shows the hour's values.

## The record

The observer read the instruments at 07:00, so a date's line holds the 24 hours up to that
morning: its Max is nearly always the afternoon before, its Min that morning's dawn, its rain
the 24 hours from 07:00 the day before. `build_data.py` moves each value onto the day it
belongs to: in `daily.csv` a date's high is that afternoon, its rain the 24 hours from 07:00
that day.

- **Gaps.** A missing high or low of up to three days is filled in on a straight line
  between its neighbours. Longer gaps stay empty: 36 days, nearly all of October and the
  first half of November 1993, where the game's own temperature runs. It is handed over, not
  switched: across the stretch of the day's curve that runs into a gap (or out of one) the
  record's share goes from all to none (`setModdedInterpolate`), so the air moves less than a
  degree in ten minutes. The record's first night and last evening ease in and out the same
  way, from and to midnight. Nine days have no rain
  figure; on those the rain, clouds and fog are the game's.
- **Flags.** Values marked `s` (failed one of NCEI's checks) are used as they are; the
  -22 F (-30 C) of 19-20 January 1994 is one of the unflagged ones, and it was real.
- **Rain times.** The record has only a day's total, so the hours it fell in are made up,
  once, with a fixed seed, and written into the data: a summer day's rain (May-September) is an
  afternoon storm of up to six hours, a winter day's a longer spell at any hour. The rate in
  inches an hour becomes the game's 0..1 intensity as 0.15 + 2.5 x rate.
- **Thunder.** The record does not say which rain was a thunderstorm, but in a Kentucky
  summer a heavy day's rain nearly always is: a May-September day with half an inch or more is
  marked as one (35 days in the two years).

## The hour's weather

| | |
|---|---|
| Temperature | the low at 06:00, the high at 15:00, a cosine between, and down to the next day's low |
| Rain or snow | the day's spell, with half-hour edges; snow at or below 0.5 C, or 3 C on a day the record has measurable snowfall |
| Clouds | overcast in the rain, gathering three hours before it and clearing two after; otherwise from the day's spread of temperature (14 C or more is a clear sky, 4 C or less a grey one) |
| Fog | at dawn after a wet day under a clear sky, and valley fog on clear mornings in August to October; gone by 10:00 |
| Wind | a light breeze, more in the afternoon, more again in the rain; the direction is the game's |
| Thunder | on a thunderstorm day, when its rain starts: thunder clouds the way the game's own storms make them, strength 0.4 + 0.6 x the rain's intensity, lasting as long as the rain; a strong one (over 0.7) is two clouds and heads for a player |
| Humidity | the game's |

## How it fits the game

- **The mod slot.** Every climate value (`ClimateManager$ClimateFloat`) has a slot for mods:
  `setEnableModded`, `setModdedValue`, `setModdedInterpolate`. The game blends it over its own
  value (at 1, it replaces it), never saves it, and an admin's weather override still wins
  over it in single player. So removing the mod leaves nothing behind in the save.
- **No weather of the game's own.** While the record runs, `setEnabledWeatherGeneration(false)`
  stops the game starting new storms, and `stopWeatherAndThunder()` ends one already going,
  once, when the record takes over. Neither is saved, so it is done again at each load. Past
  9 July 1995 generation is switched back on and every slot released. (The game's
  `getEnabledWeatherGeneration()` returns the opposite of what it says, so the mod keeps its
  own note.)
- **How often.** Once every ten game minutes (EveryTenMinutes: 15 real seconds at the default
  hour-long day), and only the values that moved are sent: the game keeps a mod slot's value
  until it is changed. Every value is sent again once an hour and at load. Working out the hour
  is a few lookups in the day's row and a cosine, nothing searched.
- **Thunder clouds** are started with `ThunderStorm:startThunderCloud` on the server or in single
  player, once a storm; the game saves them and sends their thunder to players. On a load in
  the middle of a storm the clouds are stopped with the game's own weather and started again
  for the hours left.
- **Multiplayer.** Every machine works out the same hour from the same date and sets the
  slots; only the server (or single player) switches the game's own weather off. Not yet
  tried on a server.
- **The calendar date decides.** A game started on another date picks the record up when its
  calendar reaches 9 July 1993, and lets go after 9 July 1995.

## Not done

- Not yet run in the game.
