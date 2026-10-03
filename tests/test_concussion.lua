-- Offline test for DanTraits_Concussion.lua and DanTraits_Faint.lua: what
-- counts as a knock (falls, crashes, weapon hits on the head) and how bad;
-- a helmet; a second knock on top; knocked out when severe (passing out
-- through the sleep system, and coming round); the headache, nausea,
-- dizzy falls, tiredness, endurance, light; healing with rest and sleep,
-- strain dragging it out; the sleep-light hook; sandbox; commands.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.rollf = 0.5
BodyPartType = { Head = "Head", ToIndex = function(t) return 0 end }
local faded = nil
UIManager = { FadeOut = function() faded = true end, FadeIn = function() faded = false end }

H.load("Faint", "Concussion")
H.expectHooks("OnPlayerGetDamage", "OnWeaponSwing")
H.expectEvery("minute", "Concussion")
H.expectEvery("frame", "Concussion")

-- a head that reports its health and pain, and one limb whose wounds are counted (a faint ends on a wound)
local newPlayer = H.factory(nil, function(p)
  local head = { _health = 100, _pain = 0 }
  function head:getHealth() return self._health end
  function head:getAdditionalPain() return self._pain end
  function head:setAdditionalPain(v) self._pain = v end
  p._head, p._defense, p._wounds = head, 0, 0
  p.setBlockMovement = function(_, b) p._blocked = b end
  p.setIgnoreMovement = function() end
  p.setAuthorizeMeleeAction = function() end
  p.setAuthorizeShoveStomp = function() end
  p.isSitOnGround = function() return p._sitting == true end
  p.reportEvent = function(_, e) if e == "EventSitOnGround" then p._sitting = true end end
  p.getBodyPartClothingDefense = function() return p._defense end
  local limb = { getScratchTime = function() return p._wounds end, getCutTime = function() return 0 end,
    getBiteTime = function() return 0 end, getDeepWoundTime = function() return 0 end }
  p.getBodyDamage = function() return { getBodyPart = function() return head end,
    getBodyParts = function() return { size = function() return 1 end, get = function() return limb end } end } end
end)
local halo, near = H.halo, H.near
local minute, damage, frame, swing, tick = H.minute, H.on("OnPlayerGetDamage"), H.frame, H.on("OnWeaponSwing"), H.on("OnTick")
local function out(p) return DanTraits_IsPassedOut(p) end
-- let a blackout run its course: game minutes and real seconds
local function wake(minutes) H.hours = H.hours + minutes / 60; H.now = H.now + 60000; tick() end
local function D(p) return p._md.DanTraits end

-- 1. falls: under 3 nothing; the chance climbs to certain at 15; how bad from 0.25 up
local p = newPlayer(); H.current = p
H.rollf = 0
damage(p, "FALLDOWN", 2.5); assert(D(p).ccScore == nil and D(p).ccLastImpact == "FALLDOWN 2.5", "a light fall: nothing, but noted")
H.rollf = 0.49; damage(p, "FALLDOWN", 9); near(D(p).ccScore, 0.25 + 0.04 * 6, 1e-9, "fall of 9 (a high drop): 50% chance, roll 0.49 takes; 0.49")
assert(halo[#halo] == "UI_DanTraits_ConcussionModerate" and not out(p), "moderate: ears ringing; this roll (0.49) misses the 25% blackout")
p = newPlayer(); H.current = p; H.rollf = 0.51
damage(p, "FALLDOWN", 9); assert(D(p).ccScore == nil, "roll 0.51: missed")
damage(p, "FALLDOWN", 1000); assert(D(p) == nil or D(p).ccScore == nil, "a lethal fall is the game's business")

-- 1b. crashes on their own scale: a bump into a sign (~20) nothing; 40 a third of a chance, moderate; 70 certain, severe
p = newPlayer(); H.current = p; H.rollf = 0
damage(p, "CARCRASHDAMAGE", 19.8)
assert(D(p).ccScore == nil and D(p).ccLastImpact == "CARCRASHDAMAGE 19.8", "a low-speed bump: nothing, but noted")
H.rollf = 0.34; damage(p, "CARCRASHDAMAGE", 40); assert(D(p).ccScore == nil, "40: a third of a chance, 0.34 misses")
H.rollf = 0.32; damage(p, "CARCRASHDAMAGE", 40); near(D(p).ccScore, 0.25 + 0.012 * 15, 1e-9, "40: 0.43, moderate")
if out(p) then wake(5) end
p = newPlayer(); H.current = p; H.rollf = 0.99
damage(p, "CARHITDAMAGE", 70); near(D(p).ccScore, 0.25 + 0.012 * 45, 1e-9, "hit by a car at 70: certain, 0.79")
assert(out(p), "severe: knocked out"); wake(20)
assert(string.find(DanTraits_ExtraCommands.concussion(newPlayer(), { "crash", "10" }), "a crash of 10: concussion 0", 1, true), "crash command")
-- 1c. in a car the top speed in the second before decides (the game's amount levels off: measured 42 at 49 km/h, 47 at 71)
local function drive(p, kmh) p.getVehicle = function() return { getCurrentSpeedKmHour = function() return kmh end } end; H.frame(p) end
p = newPlayer(); H.current = p; H.now = 500000; H.rollf = 0
drive(p, 11); H.now = H.now + 200; drive(p, 3)   -- the crash slows the car; the top speed stands
damage(p, "CARCRASHDAMAGE", 41.5)
assert(D(p).ccScore == nil and D(p).ccLastImpact == "CARCRASHDAMAGE 41.5 at 11 km/h", "11 km/h: nothing, whatever the amount says: " .. tostring(D(p).ccLastImpact))
H.now = H.now + 5000; drive(p, 49); H.rollf = 0.5; damage(p, "CARCRASHDAMAGE", 42.3)
near(D(p).ccScore, 0.25 + 0.01 * 24, 1e-9, "49 km/h: about half a chance (roll 0.5 takes), moderate 0.49")
if out(p) then wake(5) end
p = newPlayer(); H.current = p; H.now = H.now + 5000; H.rollf = 0.99
drive(p, 71); damage(p, "CARCRASHDAMAGE", 46.7)
assert((D(p).ccScore or 0) >= 0.7 and out(p), "71 km/h: certain and severe, knocked out, though the amount was only 46.7")
wake(20)
p.getVehicle = nil

-- 2. mild: a notice, no blackout
p = newPlayer(); H.current = p; H.rollf = 0.99; H.clearHalo()
DanTraits_KnockHead(p, 1, 0.3)
assert(D(p).ccScore == 0.3 and halo[1] == "UI_DanTraits_ConcussionMild" and not out(p), "mild")

-- 3. severe: knocked out, 5-15 game minutes by how bad (never under 8 real
-- seconds): the fall, sat on the floor, screen black, held; then comes round
p = newPlayer(); H.current = p; H.clearHalo()
DanTraits_KnockHead(p, 1, 0.85)
assert(out(p) and p._bump == "stagger" and p._vars.BumpFall == true and p._blocked and faded, "out: fallen, blocked, black")
H.now = H.now + 1000; tick(); assert(not p._sitting, "the fall plays out first")
H.now = H.now + 1000; tick(); assert(p._sitting, "then sat on the floor")
H.hours = H.hours + 9.9 / 60; H.now = H.now + 60000; tick(); assert(out(p), "0.85: ten game minutes, not yet")
H.hours = H.hours + 0.2 / 60; tick()
assert(not out(p) and not p._blocked and faded == false and halo[#halo] == "UI_DanTraits_ConcussionComeTo", "comes round")
DanTraits_PassOut(p, 0.1); H.hours = H.hours + 1; H.now = H.now + 5000; tick(); assert(out(p), "at least 8 real seconds")
H.now = H.now + 3100; tick(); assert(not out(p), "then round")

-- 3b. a faint ends when something wounds you; a knockout (deep) doesn't
p = newPlayer(); H.current = p; H.clearHalo()
DanTraits_PassOut(p, 10)
for _ = 1, 10 do tick() end; assert(out(p), "nothing happening: still out")
H.now = H.now + 5000   -- past the landing
p._wounds = 1; for _ = 1, 10 do tick() end
assert(not out(p) and halo[#halo] == "UI_DanTraits_JoltedAwake", "bitten: jolted awake")
p = newPlayer(); H.current = p
DanTraits_PassOut(p, 10, nil, true); p._wounds = 1; for _ = 1, 20 do tick() end
assert(out(p), "knocked out: stays down"); wake(20)

-- 4. a helmet: less likely, less bad
p = newPlayer(); H.current = p; p._defense = 80
H.rollf = 0.5; DanTraits_KnockHead(p, 1, 0.5)
assert(D(p) == nil or D(p).ccScore == nil, "helmet: 40% chance, roll 0.5 misses")
H.rollf = 0.3; DanTraits_KnockHead(p, 1, 0.5); near(D(p).ccScore, 0.3, 1e-9, "helmet: 0.5 x 0.6")

-- 5. a second knock lands on top; severe by stacking knocks you out
p = newPlayer(); H.current = p; H.rollf = 0.99
DanTraits_KnockHead(p, 1, 0.3); DanTraits_KnockHead(p, 1, 0.5)
near(D(p).ccScore, 0.5 + 0.5 * 0.3, 1e-9, "stacked: 0.65")
DanTraits_KnockHead(p, 1, 0.3); near(D(p).ccScore, 0.65 + 0.15, 1e-9, "past severe")
assert(out(p), "and out"); wake(20)

-- 6. weapon hits count by what they took off the head
p = newPlayer(); H.current = p; H.rollf = 0.4
frame(p); p._head._health = 90; damage(p, "WEAPONHIT", 3)
near(D(p).ccScore, 0.25 + 0.025 * 10, 1e-9, "10 off the head: 50% chance, 0.5")
local q = newPlayer(); H.current = q
frame(q); damage(q, "WEAPONHIT", 3); assert(D(q) == nil or D(q).ccScore == nil, "a hit elsewhere: nothing")

-- 7. symptoms: headache, queasy (moderate), tired, slower endurance
p = newPlayer(); H.current = p; H.rollf = 0.99
DanTraits_KnockHead(p, 1, 0.3); minute()
near(p._head._pain, 15 + 35 * D(p).ccScore, 1e-9, "headache")
assert(p._st.foodsick == 0 and p._st.fatigue > 0, "mild: not queasy, drowsy")
DanTraits_KnockHead(p, 1, 0.5); minute()
near(p._st.foodsick, 0.3 * D(p).ccScore * 100, 1e-6, "moderate: queasy")
p._st.endurance = 0.5; frame(p); p._st.endurance = 0.6; frame(p)
near(p._st.endurance, 0.5 + 0.1 * (1 - 0.3 * D(p).ccScore), 1e-9, "slower endurance")

-- 8. running when moderate: a dizzy fall
p = newPlayer(); H.current = p; H.rollf = 0.99
DanTraits_KnockHead(p, 1, 0.6); H.clearHalo(); p._bump = nil
p._run = true; frame(p); H.rollf = 0.05; minute(); p._run = false
assert(p._bump == "stagger" and halo[#halo] == "UI_DanTraits_ConcussionDizzy", "dizzy fall")

-- 9. healing: 0.25 a day at rest, x2 asleep; strain stops it and adds a little
p = newPlayer(); H.current = p; H.rollf = 0.99
DanTraits_KnockHead(p, 1, 0.3); local s = D(p).ccScore
minute(); near(D(p).ccScore, s - 0.25 / 1440, 1e-9, "resting")
s = D(p).ccScore; p._asleep = true; minute(); p._asleep = false
near(D(p).ccScore, s - 0.5 / 1440, 1e-9, "asleep: twice")
s = D(p).ccScore; swing(p); minute(); near(D(p).ccScore, s + 0.0005, 1e-9, "a fight: worse")
D(p).ccScore = 0.02; H.clearHalo(); minute(); minute()
assert(halo[#halo] == "+UI_DanTraits_ConcussionClear", "dropping under the last tier says it has cleared")
for _ = 1, 90 do minute() end
assert(D(p).ccScore == nil, "and the last trace fades to nothing")

-- 10. light wakes a concussed sleeper more easily
p = newPlayer(); H.current = p; p._md.DanTraits = { ccScore = 0.5 }
near(DanTraits_RunHooks("sleepWake", 1, p, D(p)), 1.5, 1e-9, "sleep: light wakes x1.5")

-- 11. sandbox switch, commands
SandboxVars = { DanTraits = { ConcussionEnabled = false } }
p = newPlayer(); H.current = p; H.rollf = 0; damage(p, "FALLDOWN", 14)
assert(D(p) == nil or D(p).ccScore == nil, "off: no concussion")
SandboxVars = nil
p = newPlayer(); H.current = p; H.rollf = 0.99
assert(DanTraits_ExtraCommands.concussion(p, { "0.3" }) == "concussion 0.3", "set")
assert(DanTraits_ExtraCommands.concussion(p, { "clear" }) == "concussion cleared" and D(p).ccScore == nil, "clear")
assert(string.find(DanTraits_ExtraCommands.faint(p, { "out", "5" }), "out for 5 game minutes: true", 1, true) and out(p), "faint out")

-- 11. Vitality's reach: healing x (1 + 0.25 e)
H.load("Vitality")   -- loaded last: it runs for everyone. Its effect is stubbed to +1 / -1 from here.
local vitE = 0
DanTraits_VitalityEffect = function() return vitE end
for _, case in ipairs({ { 1, 1.25 }, { -1, 0.75 }, { 0, 1 } }) do
  vitE = case[1]
  p = newPlayer(); H.current = p; H.rollf = 0.99
  DanTraits_KnockHead(p, 1, 0.3); s = D(p).ccScore
  minute(); near(D(p).ccScore, s - 0.25 / 1440 * case[2], 1e-9, "concussion heals x" .. case[2] .. " at e = " .. case[1])
end
vitE = 1; p = newPlayer(); H.current = p; DanTraits_KnockHead(p, 1, 0.3); s = D(p).ccScore; p._asleep = true; minute(); p._asleep = false
near(D(p).ccScore, s - 0.5 / 1440 * 1.25, 1e-9, "asleep: the factor rides on the doubled rate")

-- 12. the knock hooks (Thick Skull, DanTraits_Positives.lua): chance and how bad are cut before a helmet's cut
local thick = true
DanTraits_AddHook("concussionChance", function(c) if thick then return c * 0.5 end end)
DanTraits_AddHook("concussionScore", function(s) if thick then return s * 0.75 end end)
p = newPlayer(); H.current = p; p._defense = 80
H.rollf = 0.25; DanTraits_KnockHead(p, 1, 0.4)
assert(D(p) == nil or D(p).ccScore == nil, "hooks and helmet: 1 x 0.5 x 0.4 = a 20% chance, roll 0.25 misses")
H.rollf = 0.15; DanTraits_KnockHead(p, 1, 0.4); near(D(p).ccScore, 0.4 * 0.75 * 0.6, 1e-9, "hooks and helmet: 0.4 x 0.75 x 0.6")
thick = false

-- 13. the headache that comes back: chance 0.5 + 0.5 x score; a day to two and a half later (24-60 h, the
-- harness's ZombRandFloat gives the middle: 42 h); builds over 6 h, holds, fades over the last 12; lasts 24 + 24 x score h
p = newPlayer(); H.current = p
H.rollf = 0.8; DanTraits_KnockHead(p, 1, 0.5)
assert(D(p).ccLate == nil, "score 0.5: a 75% chance, roll 0.8 misses")
p = newPlayer(); H.current = p
H.rollf = 0.7; DanTraits_KnockHead(p, 1, 0.5)
assert(D(p).ccLate and D(p).ccLate.wait == 42 and D(p).ccLate.s == 0.5, "roll 0.7 hits: due in 42 hours")
H.rollf = 0.7; DanTraits_KnockHead(p, 1, 0.2)
near(D(p).ccLate.s, 0.6, 1e-9, "a second knock before it comes: as bad as the concussion now, same wait")
assert(D(p).ccLate.wait == 42, "the wait is kept")
D(p).ccScore = nil   -- the concussion itself has cleared by then
local late = D(p).ccLate
late.wait = 1 / 60; H.clearHalo(); minute()
assert(late ~= D(p).ccLate and D(p).ccLate.left and halo[1] == "UI_DanTraits_ConcussionLate", "it comes: notice")
near(D(p).ccLate.total, 24 + 24 * 0.6, 1e-9, "38.4 hours for a 0.6")
for _ = 1, 3 * 60 - 1 do minute() end
near(p._head._pain, 0.5 * (20 + 45 * 0.6), 1e-6, "three hours in: half built up")
for _ = 1, 3 * 60 do minute() end
near(p._head._pain, 20 + 45 * 0.6, 1e-6, "six hours: at its worst, 47, worse than the knock's own")
near(DanTraits_ConcussionLateStrength(p), 0.6, 1e-9, "read by others")
local left = D(p).ccLate.left; p._asleep = true; minute(); p._asleep = false
near(D(p).ccLate.left, left - 1.5 / 60, 1e-9, "asleep: half as fast again")
D(p).ccLate.left = 6; p._head._pain = 0; minute()
near(p._head._pain, (6 - 1 / 60) / 12 * (20 + 45 * 0.6), 1e-6, "fading over its last twelve hours")
D(p).ccLate.left = 1 / 60; H.clearHalo(); minute()
assert(D(p).ccLate == nil and halo[1] == "+UI_DanTraits_ConcussionLateEnd", "over: notice")
-- the console starts one next minute; clear stops it
assert(string.find(DanTraits_ExtraCommands.concussion(p, { "late", "0.4" }), "strength 0.4"), "concussion late")
minute(); assert(D(p).ccLate and D(p).ccLate.left, "started")
DanTraits_ExtraCommands.concussion(p, { "clear" }); assert(D(p).ccLate == nil, "cleared")

H.pass()
