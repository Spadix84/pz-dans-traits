-- Offline test for DanTraits_Spoons.lua, the energy budget, with MS as its
-- user and the real Sleep and Vitality files scoring the night: spending by
-- effort, pain, panic, hunger, heat and a flare; rest; the tiers and what
-- they do; the wall and its debt; the refill on waking and its correction
-- when Vitality scores the night; naps; amantadine; the coffee mask; the
-- sandbox count; the moodle; the console.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
ISTakeWaterAction = { transferFluid = function() end }
H.load("Arthritis", "Meds", "Sleep", "Vitality", "Caffeine", "Spoons", "MS")
H.expectEvery("minute", "Spoons")

local near, halo, minute = H.near, H.halo, H.minute
local newPlayer = H.factory({ traits = { "ms" }, hours = 10 }, function(p)
  p._met = 1.5
  local parts = {}
  for name in pairs(BodyPartType) do parts[name] = { _stiff = 0, getStiffness = function(self) return self._stiff end, setStiffness = function(self, v) self._stiff = v end } end
  p._parts = parts
  local bd = p.getBodyDamage()
  bd.getBodyPart = function(_, name) return parts[name] or p._head end
  bd.getThermoregulator = function() return { getMetabolicRate = function() return p._met end } end
  p.getBodyDamage = function() return bd end
end)
local function S(p) return p._md.DanTraits end
local function said(key)
  for _, t in ipairs(halo) do if t == key or t == "+" .. key then return true end end
  return false
end
H.climate.temp = 15
local BASE = 1 / 160

-- 1. a new user starts the day full; idle costs 1/160 a minute, and idle is rest (+0.01), so the pool only creeps while under the cap
local p = newPlayer(); H.current = p
minute()
near(S(p).spPool, 12 - BASE, 1e-9, "starts at 12, one idle minute off (rest cannot go over the cap)")
assert(S(p).spCap == 12 and S(p).spTier == 0 and S(p).spFelt == 0, "cap 12, nothing to show")
near(S(p).spRest, 0.01, 1e-9, "the idle minute counted as rest")

-- 2. spending by effort: walking, sprinting; pain, panic and hunger; heat and a flare (MS's hook)
DanTraits_SpoonsSet(p, 10)
p._met = 3; minute(); near(S(p).spPool, 10 - (BASE + 0.0075 * 1.5), 1e-9, "walking: 1.5 MET above rest")
DanTraits_SpoonsSet(p, 10)
p._met = 8; minute(); near(S(p).spPool, 10 - (BASE + 0.0075 * 6.5), 1e-9, "sprinting: about 3.3 an hour")
DanTraits_SpoonsSet(p, 10); p._met = 3
p._st.pain = 50; minute(); near(S(p).spPool, 10 - (BASE + 0.0075 * 1.5) * 1.15, 1e-9, "pain 50: x1.15"); p._st.pain = 0
DanTraits_SpoonsSet(p, 10)
p._st.panic = 100; minute(); near(S(p).spPool, 10 - (BASE + 0.0075 * 1.5) * 1.3, 1e-9, "full panic: x1.3"); p._st.panic = 0
DanTraits_SpoonsSet(p, 10)
p._st.hunger = 0.3; minute(); near(S(p).spPool, 10 - (BASE + 0.0075 * 1.5) * 1.2, 1e-9, "hungry: x1.2"); p._st.hunger = 0
DanTraits_SpoonsSet(p, 10)
S(p).msHeat = 0.5; minute(); near(S(p).spPool, 10 - (BASE + 0.0075 * 1.5) * 1.5, 1e-9, "heat load 0.5: x1.5"); S(p).msHeat = nil
H.mins(30)   -- let the heat tier clear
DanTraits_SpoonsSet(p, 10)
S(p).msFlareH = 10; minute()
near(S(p).spCap, 8, 1e-9, "a flare caps the pool at two thirds")
near(S(p).spPool, 8 - (BASE + 0.0075 * 1.5) * 1.5, 1e-9, "...and the pool is clamped to it, then spends x1.5")
S(p).msFlareH = nil; minute(); near(S(p).spCap, 12, 1e-9, "the flare over: the cap is back")

-- 3. rest: idle, not hungry, not heavy, not driving gives 0.01 a minute, up to 2 a day
DanTraits_SpoonsSet(p, 5); p._met = 1.5; S(p).spRest = 0
minute(); near(S(p).spPool, 5 + 0.01 - BASE, 1e-9, "resting: half a spoon an hour back, less the idle cost")
p._met = 1.8; minute(); near(S(p).spPool, 5 + 0.01 - BASE - (BASE + 0.0075 * 0.3), 1e-9, "1.8 MET is not rest")
p._met = 1.5; p.getVehicle = function() return {} end; local before = S(p).spPool
minute(); near(S(p).spPool, before - BASE, 1e-9, "driving is not rest"); p.getVehicle = nil
S(p).spRest = 1.995; minute(); near(S(p).spRest, 2, 1e-9, "the day's rest is capped at 2")
before = S(p).spPool; minute(); near(S(p).spPool, before - BASE, 1e-9, "...and gives nothing more")

-- 4. the tiers: half gone (a notice once a day), running on empty (stamina x0.7, tiring, legs 20),
--    the wall (stamina x0.4, very tired, legs 35, a slipping swing, borrowing an hour an hour)
local t = newPlayer(); H.current = t
minute(); t._met = 3
H.clearHalo(); DanTraits_SpoonsSet(t, 6); minute()
assert(S(t).spTier == 1 and S(t).spFelt == 1 and halo[#halo] == "UI_DanTraits_SpoonsHalf", "at or under half: half gone, with a notice")
H.clearHalo(); DanTraits_SpoonsSet(t, 6); minute(); assert(#halo == 0, "the half notice comes once a day")
assert(DanTraits_RunHooks("enduranceRegen", 1, t, S(t)) == 1, "half gone: stamina untouched")
t._st.fatigue = 0; DanTraits_SpoonsSet(t, 3); minute()
assert(S(t).spTier == 2, "three or fewer: running on empty")
near(t._st.fatigue, 0.0004, 1e-9, "running on empty: tiring")
near(DanTraits_RunHooks("enduranceRegen", 1, t, S(t)), 0.7, 1e-9, "running on empty: stamina x0.7")
near(t._parts.LowerLeg_L._stiff, 20, 1e-9, "running on empty: the legs stiffen (MS)")
H.clearHalo(); t._st.fatigue = 0; DanTraits_SpoonsSet(t, 0.001); minute()
assert(S(t).spTier == 3 and halo[#halo] == "UI_DanTraits_SpoonsWall", "nothing left: the wall, with a notice")
near(t._st.fatigue, 0.0010, 1e-9, "the wall: very tired")
near(DanTraits_RunHooks("enduranceRegen", 1, t, S(t)), 0.4, 1e-9, "the wall: stamina x0.4")
near(t._parts.LowerLeg_L._stiff, 35, 1e-9, "the wall: legs like a flare (MS)")
near(DanTraits_SwingDropChance(t), 5, 1e-9, "the wall: a swing can throw the weapon (MS)")
near(S(t).spDebt, 1 / 60, 1e-9, "a minute at the wall borrows a sixtieth of an hour")
H.mins(59); near(S(t).spDebt, 1, 1e-9, "an hour at the wall: an hour borrowed"); assert(S(t).spWallMin == 60, "counted")
near(DanTraits_MSFlareRate(t, S(t)), 1.1 / 720, 1e-12, "an hour borrowed: flares x1.1 (MS)")
H.mins(6 * 60); near(S(t).spDebt, 6, 1e-9, "no more than six hours")
H.clearHalo(); t._met = 1.5; minute()
assert(S(t).spPool > 0 and S(t).spTier == 2, "sitting down at the wall: rest lifts you off it")
assert(DanTraits_RunHooks("enduranceRegen", 1, t, { spFelt = 0 }) == 1 and DanTraits_RunHooks("enduranceRegen", 1, t, {}) == 1, "nothing without a tier")
t._asleep = true; minute(); assert(S(t).spFelt == 0 and S(t).spTier == 0, "asleep: no tier"); t._asleep = false

-- 5. the refill: a full dark night pays the debt and fills the rest; corrected when Vitality scores it
local n = newPlayer({ hours = 100 }); H.current = n
minute(); S(n).spDebt = 1; DanTraits_SpoonsSet(n, 2); n._light = 0   -- dark
n._asleep = true; minute()                              -- the first minute asleep: start recorded
assert(S(n).spAsleep and S(n).spSleepStart == 100 and S(n).spFelt == 0, "asleep from hour 100")
H.mins(10)                                              -- the Sleep file counts the dark minutes
n._hours = 108; n._asleep = false; n._st.fatigue = 0; H.clearHalo()
minute()
near(S(n).spPool, 11 + 0.01 - BASE, 1e-9, "up after 8 dark hours, rested: 12 x 1 less the hour borrowed, then the first idle minute")
assert(halo[#halo] == "UI_DanTraits_SpoonsTodayDebt:11", "the morning notice says 11, paying for yesterday")
assert(S(n).spDebt == 0 and S(n).spDebtPaid == 1 and S(n).spRest == 0.01 and S(n).spWallMin == 0, "the debt is paid and the day's counters are fresh")
H.mins(59)                                              -- Vitality scores the night on the 60th minute up
assert(S(n).vitLastSleepQuality == 1 and S(n).vitNightHours == 0, "Vitality scored a perfect night")
near(S(n).spPool, 11 + 60 * (0.01 - BASE), 1e-9, "re-scored: the same refill, and what rest gave back is kept")
near(S(n).spLastQuality, 1, 1e-9, "the night's score is remembered")
-- a bad night: lit, four hours, woke tired: a third of the cap plus two thirds of the score
local b = newPlayer({ hours = 200 }); H.current = b
minute(); DanTraits_SpoonsSet(b, 1); b._light = 1; H.roll = 9999   -- lit, but the light does not wake you here
b._asleep = true; minute(); H.mins(10)
b._hours = 204; b._asleep = false; b._st.fatigue = 0.5; H.clearHalo()
minute()
local q = 0.5 * (4 / 7) + 0.5 * 0.5 - 0.15
near(S(b).spPool, 12 * (1 / 3 + 2 / 3 * q) + 0.01 - BASE, 1e-9, "a bad night: 7 spoons")
assert(halo[#halo] == "UI_DanTraits_SpoonsTodayBad:7", "the morning notice says so")
H.mins(59)
near(S(b).spLastQuality, q, 1e-9, "Vitality's score agrees (the lit room is the Sleep file's penalty)")
assert(said("UI_DanTraits_SleptBadly2"), "and Slept Badly says its piece too: a bad night costs twice, by design")
H.roll = 0
-- the worst night still gives a third
local w = newPlayer({ hours = 300 }); H.current = w
minute(); DanTraits_SpoonsSet(w, 0); w._light = 1; H.roll = 9999
w._asleep = true; minute(); w._hours = 303; w._asleep = false; w._st.fatigue = 1; H.clearHalo(); minute(); H.roll = 0
local qw = 0.5 * (3 / 7) - 0.15   -- three hours of a seven-hour need, not rested at all, a lit room
near(S(w).spPool, 12 * (1 / 3 + 2 / 3 * qw) + 0.01 - BASE, 1e-9, "3 lit hours, exhausted: a third of the cap plus a sliver, 4.5")
assert(S(w).spPool >= 4, "never under a third of the cap")
-- amantadine built up adds two to the refill
local a = newPlayer({ hours = 400 }); H.current = a
minute(); DanTraits_RunHooks("pill", nil, a, "Amantadine"); S(a).meds.amantadine.built = 1
S(a).spDebt = 2; a._light = 0
a._asleep = true; minute(); a._hours = 408; a._asleep = false; a._st.fatigue = 0; minute()
near(S(a).spPool, 12 + 0.01 - BASE - 0.01, 1e-9, "12 - 2 borrowed + 2 from amantadine: full (rest cannot go over)")

-- 6. naps: under three hours, up to four a day, no reset; two naps close together are one night (Vitality's rule)
local z = newPlayer({ hours = 500 }); H.current = z
minute(); DanTraits_SpoonsSet(z, 5); z._light = 0
z._asleep = true; minute(); z._hours = 502; z._asleep = false; minute()
near(S(z).spPool, 5 + 4 * 2 / 3 + 0.01 - BASE, 1e-9, "a two-hour dark nap: 2.67 back")
near(S(z).spNap, 4 * 2 / 3, 1e-9, "counted")
H.mins(61)   -- Vitality scores it as a nap (debt halved, nothing for the pool)
assert(S(z).vitNightHours == 0, "scored as a nap")
local before = S(z).spPool
z._hours = 504; z._asleep = true; minute(); z._hours = 506; z._asleep = false; minute()
near(S(z).spPool, before + (4 - 4 * 2 / 3) + 0.01 - BASE, 1e-9, "the second nap: only what is left of the day's four")
H.mins(61)
before = S(z).spPool
z._hours = 510; z._asleep = true; minute(); z._hours = 512; z._asleep = false; minute()
near(S(z).spPool, before + 0.01 - BASE, 1e-9, "the third: nothing")
-- two short sleeps ten minutes apart: the second wake sees the first's hours too, and it is a night
local r = newPlayer({ hours = 600 }); H.current = r
minute(); DanTraits_SpoonsSet(r, 1); r._light = 0
r._asleep = true; minute(); r._hours = 602.5; r._asleep = false; minute()
near(S(r).spNap, 4 * 2.5 / 3, 1e-9, "the first half: a nap")
H.mins(10)
r._asleep = true; minute(); r._hours = 605.5; r._asleep = false; r._st.fatigue = 0; H.clearHalo(); minute()
local qr = 0.5 * (5.5 / 7) + 0.5 + 0.1   -- 2.5 + 3 hours, rested, dark
assert(halo[#halo] == "+UI_DanTraits_SpoonsToday:12", "the second half makes it a night of 5.5 hours: a fresh refill, said in the morning")
near(S(r).spPool, 12 * (1 / 3 + 2 / 3 * qr) + 0.01 - BASE, 1e-9, "...of 11.9")

-- 7. a coffee hides a tier for an hour (through the Caffeine file's dose, for anyone with a budget)
local c = newPlayer(); H.current = c
minute(); c._met = 3; DanTraits_SpoonsSet(c, 2); minute()
assert(S(c).spTier == 2 and S(c).spFelt == 2, "running on empty")
H.clearHalo()
local mug = { getType = function() return "HotDrinkWhite" end, haveExtraItems = function() return true end,
  getExtraItems = function() return { size = function() return 1 end, get = function() return "Base.Coffee2" end } end }
DanTraits_RunHooks("eat", nil, c, mug, 1)
near(S(c).spMask, 60, 1e-9, "a mug of coffee: masked for an hour"); assert(halo[#halo] == "UI_DanTraits_SpoonsCoffee", "and says so")
c._st.fatigue = 0; minute()
assert(S(c).spTier == 2 and S(c).spFelt == 1 and c._st.fatigue == 0, "felt as half gone: no tiring")
near(DanTraits_RunHooks("enduranceRegen", 1, c, S(c)), 1, 1e-9, "stamina untouched while it lasts")
DanTraits_SpoonsSet(c, 0.0001); minute(); assert(S(c).spTier == 3 and S(c).spFelt == 2, "the wall felt as running on empty")
H.clearHalo(); H.mins(57); assert(S(c).spMask == 1 and S(c).spFelt == 2, "still masked")
minute(); assert(S(c).spMask == nil and S(c).spFelt == 3 and halo[#halo] == "UI_DanTraits_SpoonsWall", "the hour up: the wall lands")
assert(said("UI_DanTraits_SpoonsCoffeeGone"), "and the coffee is gone")
DanTraits_SpoonMask(c, 20); near(S(c).spMask, 30, 1e-9, "a small dose: pro rata")
DanTraits_SpoonMask(c, 100); near(S(c).spMask, 60, 1e-9, "a bigger one takes over, no stacking")
DanTraits_SpoonsSet(c, 10); S(c).spMask = nil; minute(); H.clearHalo()
DanTraits_SpoonMask(c, 100); assert(#halo == 0, "no notice when there is nothing to hide")

-- 8. the sandbox count: 0 is no budget (MS's old drip is back), 6 is a six-spoon day
local s = newPlayer(); H.current = s
minute(); assert(S(s).spPool ~= nil, "on by default")
SandboxVars = { DanTraits = { MSSpoons = 0 } }
minute(); assert(S(s).spPool == nil and S(s).spCap == nil and S(s).spFelt == nil, "off: nothing kept")
SandboxVars = { DanTraits = { MSSpoons = 6 } }
minute(); assert(S(s).spCap == 6 and S(s).spPool == 6 - BASE, "six a day, starting full")
DanTraits_SpoonsSet(s, 1.5); s._met = 3; minute(); assert(S(s).spTier == 2, "a quarter of a small cap is running on empty")
SandboxVars = nil

-- 9. without a user nothing is stored; the moodle; the console
local none = newPlayer({ traits = {} }); H.current = none
minute(); assert(S(none) == nil or S(none).spPool == nil, "no trait: no pool")
assert(DanTraits_SpoonTier(none) == 0 and DanTraits_SpoonDebt(none) == 0 and DanTraits_SpoonsSet(none, 5) == nil, "and nothing to read or set")
H.load("Moodles")
assert(DanTraits_MoodleLevels(none, { spFelt = 3 }).Spoons == 3 and DanTraits_MoodleLevels(none, {}).Spoons == 0, "the moodle shows the felt tier")
H.current = p
assert(DanTraits_ExtraCommands.ms(p, { "spoons", "5" }):find("spoons 5 of 12", 1, true), "ms spoons 5")
assert(DanTraits_ExtraCommands.ms(p, { "spoons", "debt", "2" }):find("spoon debt 2", 1, true) and S(p).spDebt == 2, "ms spoons debt 2")
assert(DanTraits_ExtraCommands.ms(p, {}):find("spoons 5", 1, true), "the summary says")

H.pass()
