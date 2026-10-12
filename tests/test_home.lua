-- Offline test for DanTraits_Home.lua: where a night is filed (building,
-- camp, vehicle, nap), when a place becomes home and when home moves, the
-- nights-at-home count and strength, what being at home does (the drains,
-- the night's score, reading), missing home and coming back, Homebody's
-- doubling and earlier homesickness, Nomad's nothing, and the sandbox switch.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
ISReadABook = { getDuration = function(self) return 100 end }
H.load("Home")
H.expectHooks("OnGameStart")
H.expectEvery("minute", "Home")

local near = H.near
local minute = H.minute

-- a player standing (and sleeping) somewhere: opts.b = { x1, y1, x2, y2 } puts
-- them inside that building, opts.x / opts.y where they stand
local function newPlayer(o)
  o = o or {}
  local p = H.player(o)
  p._x, p._y, p._b, p._vehicle = o.x or 100, o.y or 100, o.b, nil
  p.getVehicle = function() return p._vehicle end
  p.getX = function() return p._x end
  p.getY = function() return p._y end
  p.getCurrentSquare = function()
    local b = p._b
    return {
      getX = function() return p._x end, getY = function() return p._y end, getZ = function() return 0 end,
      getBuildingDef = function()
        if not b then return nil end
        return { getX = function() return b[1] end, getY = function() return b[2] end, getX2 = function() return b[3] end, getY2 = function() return b[4] end }
      end,
      getBuilding = function() return nil end,
      getLightLevel = function() return 0 end, isOutside = function() return b == nil end,
    }
  end
  return p
end

-- move the player: into a building (b) or to a spot in the open
local function moveTo(p, x, y, b) p._x, p._y, p._b = x, y, b end

-- one night where the player stands: fall asleep (a minute records the spot),
-- wake, then Vitality scores it; returns the night's quality from 0.5
local function night(p, hours)
  hours = hours or 7
  p._asleep = true; minute()
  p._asleep = false; minute()
  local d = DanTraits_Data(p)
  local q = DanTraits_RunHooks("nightQuality", 0.5, p, d, hours)
  DanTraits_RunHooks("nightScored", nil, p, d, q, hours, 1, hours < 3)
  return q
end

local A = { 100, 100, 110, 108 }   -- a house
local B = { 300, 300, 305, 304 }   -- another house, far away
local function listLen(p) return #(DanTraits_Data(p).hmNightList or {}) end

-- 1. the place: a building's footprint, a camp, a vehicle
local p = newPlayer({ b = A }); H.current = p
local place = DanTraits_HomePlaceOf(p)
assert(place.x == 100 and place.y == 100 and place.b and place.b[3] == 110, "inside a building: its footprint")
moveTo(p, 500, 500, nil)
place = DanTraits_HomePlaceOf(p)
assert(place.x == 500 and place.b == nil, "in the open: the spot only")
p._vehicle = {}
assert(DanTraits_HomePlaceOf(p) == nil, "in a vehicle: nowhere")
p._vehicle = nil

-- 2. the same place: one building, two camps close together, never a camp and a building
assert(DanTraits_HomeSamePlace({ x = 1, y = 1, b = A }, { x = 9, y = 9, b = A }), "two squares of one building")
assert(not DanTraits_HomeSamePlace({ x = 1, y = 1, b = A }, { x = 1, y = 1, b = B }), "two buildings")
assert(DanTraits_HomeSamePlace({ x = 500, y = 500 }, { x = 510, y = 505 }), "two camps 11 tiles apart")
assert(not DanTraits_HomeSamePlace({ x = 500, y = 500 }, { x = 520, y = 500 }), "two camps 20 tiles apart")
assert(not DanTraits_HomeSamePlace({ x = 100, y = 100, b = A }, { x = 100, y = 100 }), "a camp on a building's square is not the building")
-- at home: the footprint plus four tiles, or twenty tiles of a camp
local homeA = { x = 100, y = 100, b = A }
assert(DanTraits_HomeAtPlace(homeA, 114, 112) and not DanTraits_HomeAtPlace(homeA, 115, 100), "the pad is four tiles")
assert(DanTraits_HomeAtPlace(homeA, 96, 96) and not DanTraits_HomeAtPlace(homeA, 95, 100), "and on the near side")
local camp = { x = 500, y = 500 }
assert(DanTraits_HomeAtPlace(camp, 520, 500) and not DanTraits_HomeAtPlace(camp, 521, 500), "a camp reaches twenty tiles")
assert(not DanTraits_HomeAtPlace(nil, 1, 1), "no home: never at home")

-- 3. three nights in one place make it home
p = newPlayer({ b = A }); H.current = p
local d = DanTraits_Data(p)
night(p); night(p)
assert(d.hmHome == nil and listLen(p) == 2, "two nights: no home yet")
assert(DanTraits_HomeStrength(p) == 0, "no home: no strength")
assert(#H.halo == 0, "nothing said yet")
night(p)
assert(d.hmHome and d.hmHome.b[1] == 100 and d.hmNights == 3, "the third night: home, three nights")
assert(H.halo[#H.halo] == "+UI_DanTraits_HomeFound", "said so")
near(DanTraits_HomeStrength(p), 0.5, 1e-9, "half strength at three nights")

-- 4. more nights build it; a night away neither adds nor moves it
night(p); night(p); night(p); night(p)
assert(d.hmNights == 7, "seven nights")
near(DanTraits_HomeStrength(p), 1, 1e-9, "full strength at seven")
H.clearHalo()
moveTo(p, 300, 300, B); night(p)
assert(d.hmHome.b[1] == 100 and d.hmNights == 7, "a night elsewhere: same home, no extra night")
assert(#H.halo == 0 or H.halo[#H.halo] ~= "+UI_DanTraits_HomeMoved", "home did not move")
assert(listLen(p) == 7, "the window holds seven nights")

-- 5. home moves once the new place has the most of the last seven (ties go to the newer)
H.clearHalo()
local C = { 700, 700, 705, 705 }
moveTo(p, 700, 700, C); night(p); night(p)
assert(d.hmHome.b[1] == 100, "two nights at C, four at A: still A")
night(p)
assert(d.hmHome.b[1] == 700 and d.hmNights == 3, "three at C against three at A: C, the newer, with its three nights")
assert(H.halo[#H.halo] == "+UI_DanTraits_HomeMoved", "a new place to call home")
assert((d.hmSick or 0) == 0 and (d.hmAwayH or 0) == 0, "not missing the old one")

-- 6. at home, awake: boredom, unhappiness and stress ease by strength; the moodle shows
p = newPlayer({ b = A }); H.current = p; d = DanTraits_Data(p)
d.hmHome = { x = 100, y = 100, b = A }; d.hmNights = 7
p._st.boredom, p._st.unhappy, p._st.stress = 50, 50, 0.5
minute()
near(p._st.boredom, 49.7, 1e-9, "boredom off 0.3 a minute")
near(p._st.unhappy, 49.92, 1e-9, "unhappiness off 0.08")
near(p._st.stress, 0.4996, 1e-9, "stress off 0.0004")
assert(d.hmAtHome == true and d.hmMoodle == -2, "At Home")
d.hmNights = 3; minute()
near(p._st.boredom, 49.55, 1e-9, "half strength: half the drain")
assert(d.hmMoodle == -1, "Settling In")
-- asleep: the counters run, the drains do not
d.hmNights = 7; p._asleep = true; p._st.boredom = 50; minute(); p._asleep = false
near(p._st.boredom, 50, 1e-9, "asleep: no drain")
-- away: nothing, and the hours away count
moveTo(p, 900, 900, nil); p._st.boredom = 50; minute()
near(p._st.boredom, 50, 1e-9, "away: no drain")
assert(d.hmAtHome == false and d.hmMoodle == 0, "away, not yet missing it")
near(d.hmAwayH, 1 / 60, 1e-9, "one minute away")

-- 7. missing home: 48 hours away, full after 72; the floor; back home lifts it
d.hmAwayH = 47.99; H.clearHalo(); minute()
assert((d.hmSick or 0) > 0 and H.halo[#H.halo] == "UI_DanTraits_Homesick", "48 hours: you miss home")
assert(d.hmMoodle == 1, "Missing Home")
d.hmAwayH = 72; p._st.unhappy, p._st.stress = 0, 0.5; minute()
near(d.hmSick, 1, 1e-9, "fully homesick at 72 hours")
assert(d.hmMoodle == 2, "Homesick")
near(p._st.unhappy, 0.5, 1e-9, "the floor climbs half a point a minute")
for _ = 1, 40 do minute() end
near(p._st.unhappy, 15, 1e-9, "and stops at 15")
near(p._st.stress, 0.5, 1e-9, "no stress for everyone")
-- home again
H.clearHalo(); p._st.stress = 0.5
moveTo(p, 105, 105, A); minute()
near(p._st.unhappy, 0, 1e-9, "good to be home: 15 unhappiness off (floored at 0)")
near(p._st.stress, 0.4 - 0.0004, 1e-9, "a tenth of stress off, then the minute's drain")
assert(H.halo[#H.halo] == "+UI_DanTraits_HomeReturn", "said so")
assert(d.hmSick == 0 and d.hmAwayH == 0 and d.hmMoodle == -2, "home, and At Home again")

-- 8. a night slept at home scores better; elsewhere, for everyone, nothing
p = newPlayer({ b = A }); H.current = p; d = DanTraits_Data(p)
d.hmHome = { x = 100, y = 100, b = A }; d.hmNights = 7
near(night(p), 0.55, 1e-9, "at home: +0.05 at full strength")
d.hmNights = 3
near(night(p), 0.525, 1e-9, "half strength: +0.025")
moveTo(p, 300, 300, B)
near(night(p), 0.5, 1e-9, "away: untouched")
-- a nap or a night in the car is not filed
moveTo(p, 100, 100, A); d.hmNightList = {}
night(p, 2)
assert(listLen(p) == 0, "a nap is not a night")
p._vehicle = {}; night(p); p._vehicle = nil
assert(listLen(p) == 0, "a night in a car is nowhere")
night(p)
assert(listLen(p) == 1, "a night in the house is filed")

-- 9. reading goes faster at home
p = newPlayer({ b = A }); H.current = p; d = DanTraits_Data(p)
d.hmHome = { x = 100, y = 100, b = A }; d.hmNights = 7
minute()
local read = { character = p }
near(ISReadABook.getDuration(read), 90, 1e-9, "a tenth faster at home")
d.hmNights = 3; minute()
near(ISReadABook.getDuration(read), 95, 1e-9, "half strength: a twentieth")
moveTo(p, 900, 900, nil); minute()
near(ISReadABook.getDuration(read), 100, 1e-9, "away: as the book says")

-- 10. Homebody: twice the good at home, misses it after a day, a higher floor, stress, worse nights away
local hb = newPlayer({ traits = { "homebody" }, b = A }); H.current = hb; d = DanTraits_Data(hb)
d.hmHome = { x = 100, y = 100, b = A }; d.hmNights = 7
hb._st.boredom = 50; minute()
near(hb._st.boredom, 49.4, 1e-9, "boredom off 0.6 a minute")
near(ISReadABook.getDuration({ character = hb }), 80, 1e-9, "a fifth faster")
near(night(hb), 0.6, 1e-9, "a night at home: +0.1")
moveTo(hb, 300, 300, B)
near(night(hb), 0.4, 1e-9, "a night away: -0.1")
d.hmAwayH = 23.99; H.clearHalo(); minute()
assert((d.hmSick or 0) > 0 and H.halo[#H.halo] == "UI_DanTraits_Homesick", "24 hours: a Homebody misses home")
d.hmAwayH = 48; hb._st.unhappy, hb._st.stress = 0, 0; minute()
near(d.hmSick, 1, 1e-9, "fully homesick at 48 hours")
near(hb._st.unhappy, 0.5, 1e-9, "the floor climbs")
near(hb._st.stress, 0.0004, 1e-9, "and stress comes with it")
for _ = 1, 70 do minute() end
near(hb._st.unhappy, 30, 1e-9, "the floor stops at 30")

-- 11. Nomad: nothing tracked, nothing missed; a night under the sky scores better
local nm = newPlayer({ traits = { "nomad" }, b = A }); H.current = nm; d = DanTraits_Data(nm)
H.clearHalo()
for _ = 1, 4 do night(nm) end
assert(d.hmHome == nil and listLen(nm) == 0 and #H.halo == 0, "four nights in a house: no home")
assert(DanTraits_HomeStrength(nm) == 0 and d.hmMoodle == 0, "no strength, no moodle")
near(night(nm), 0.5, 1e-9, "a night indoors: as it was")
moveTo(nm, 500, 500, nil)
near(night(nm), 0.6, 1e-9, "a night under the sky: +0.1")
d.hmHome = { x = 100, y = 100, b = A }; d.hmNights = 7; d.hmAwayH = 100   -- a home from before the trait
nm._st.unhappy = 0; minute()
assert(d.hmSick == 0 and nm._st.unhappy == 0, "a Nomad misses nothing")

-- 12. the sandbox switch: off, nothing tracks, nothing shows, nothing applies
SandboxVars = { DanTraits = { HomeEnabled = false } }
p = newPlayer({ b = A }); H.current = p; d = DanTraits_Data(p)
d.hmHome = { x = 100, y = 100, b = A }; d.hmNights = 7; d.hmMoodle = -2
p._st.boredom = 50; minute()
near(p._st.boredom, 50, 1e-9, "off: no drain")
assert(d.hmMoodle == 0 and d.hmAtHome == nil, "off: no moodle")
assert(DanTraits_HomeStrength(p) == 0, "off: no strength")
near(night(p), 0.5, 1e-9, "off: a night is a night")
assert(listLen(p) == 0, "off: not filed")
near(ISReadABook.getDuration({ character = p }), 100, 1e-9, "off: reading as the book says")
SandboxVars = nil

H.pass()
