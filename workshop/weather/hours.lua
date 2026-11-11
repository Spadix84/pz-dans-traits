-- Prints the mod's own weather for every ten minutes of the record, as CSV lines, for
-- make_images.py (run through tests/run_all.js, so the pictures show what the mod does):
--   row, hour, temperature, share, precipitation, clouds, fog, wind, snow line, storm strength
local here = (arg and arg[0] and arg[0]:match("^(.*)/")) or "."   -- run with a forward-slash path
dofile(here .. "/../../HistoricalWeather/42/media/lua/shared/HistoricalWeather_Data.lua")
dofile(here .. "/../../HistoricalWeather/42/media/lua/shared/HistoricalWeather.lua")
local HW = HistoricalWeather
local DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local y, m, d = 1993, 7, 9
local function n(v) return v == nil and "" or string.format("%.3f", v) end
while true do
  if not HW.index(y, m, d) then break end
  for step = 0, 143 do
    local h = step / 6
    local w = HW.at(y, m, d, h)
    print(table.concat({ w.index, n(h), n(w.temperature), n(w.share), n(w.precipitation), n(w.clouds), n(w.fog),
      n(w.wind), n(w.snowLine), w.storm and n(w.storm.strength) or "" }, ","))
  end
  d = d + 1
  if d > DAYS[m] then d, m = 1, m + 1 end
  if m > 12 then m, y = 1, y + 1 end
end
