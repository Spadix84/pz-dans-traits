-- Offline test for DanTraits_Concussion.lua and DanTraits_Faint.lua: what
-- counts as a knock (falls, crashes, weapon hits on the head) and how bad;
-- a helmet; a second knock on top; knocked out when severe (passing out
-- through the sleep system, and coming round); the headache, nausea,
-- dizzy falls, tiredness, endurance, light; healing with rest and sleep,
-- strain dragging it out; the sleep-light hook; sandbox; commands.
local handlers, lists = {}, {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) lists[k] = lists[k] or {}; table.insert(lists[k], f); handlers[k] = function(...) for _, g in ipairs(lists[k]) do g(...) end end end, Remove = function() end }; rawset(t, k, e); return e end })
local function statKey(name, max) return { name = name, getMaximumValue = function() return max or 1 end } end
CharacterStat = { FATIGUE = statKey("fatigue"), ENDURANCE = statKey("endurance"), FOOD_SICKNESS = statKey("foodsick", 100) }
local halo = {}
HaloTextHelper = { addBadText = function(_, t) halo[#halo+1] = t end, addGoodText = function(_, t) halo[#halo+1] = "+" .. t end }
function getText(k) return k end
DanTraitsRegistry = {}
ISEatFoodAction = { complete = function() return true end, eat = function() end, isValid = function() return true end, isValidStart = function() return true end }
ISTakePillAction = { complete = function() return true end }
local nextRoll = 0.5
function ZombRandFloat(lo, hi) if lo == 0 and hi == 1 then return nextRoll end return (lo + hi) / 2 end
function ZombRand() return 0 end
BodyPartType = { Head = "Head", ToIndex = function(t) return 0 end }
local hours, ms = 100, 0   -- world age in game hours, the real clock in ms
GameTime = { getInstance = function() return { getWorldAgeHours = function() return hours end } end }
function getTimestampMs() return ms end
local faded = nil
UIManager = { FadeOut = function() faded = true end, FadeIn = function() faded = false end }

function require() end
for _, f in ipairs({ "DanTraits", "DanTraits_Faint", "DanTraits_Concussion" }) do
  assert(loadfile("../DanTraits/42/media/lua/shared/" .. f .. ".lua"))()
end
assert(handlers.OnPlayerGetDamage and handlers.EveryOneMinute and handlers.OnPlayerUpdate and handlers.OnWeaponSwing, "hooks in place")

local function makePlayer()
  local md = {}
  local head = { _health = 100, _pain = 0 }
  function head:getHealth() return self._health end
  function head:getAdditionalPain() return self._pain end
  function head:setAdditionalPain(v) self._pain = v end
  local st = { fatigue = 0, endurance = 1, foodsick = 0 }
  local p = { _md = md, _head = head, _st = st, _asleep = false, _sprint = false, _run = false, _defense = 0, _vars = {},
    getModData = function() return md end, isDead = function() return false end }
  function p:isAsleep() return self._asleep end
  function p:setBlockMovement(b) self._blocked = b end
  function p:setIgnoreMovement() end
  function p:setAuthorizeMeleeAction() end
  function p:setAuthorizeShoveStomp() end
  function p:getPlayerNum() return 0 end
  function p:isSitOnGround() return self._sitting == true end
  function p:reportEvent(e) if e == "EventSitOnGround" then self._sitting = true end end
  function p:setBumpType(t) self._bump = t end
  function p:setVariable(k, v) self._vars[k] = v end
  function p:isSprinting() return self._sprint end
  function p:isRunning() return self._run end
  function p:isOutside() return false end
  function p:getBodyPartClothingDefense() return self._defense end
  function p:getStats() return { get = function(_, k) return st[k.name] end, set = function(_, k, v) st[k.name] = v end } end
  p._wounds = 0
  local limb = { getScratchTime = function() return p._wounds end, getCutTime = function() return 0 end,
    getBiteTime = function() return 0 end, getDeepWoundTime = function() return 0 end }
  function p:getBodyDamage() return { getBodyPart = function() return head end,
    getBodyParts = function() return { size = function() return 1 end, get = function() return limb end } end } end
  return p
end
local current
function getSpecificPlayer() return current end
local minute, damage, frame, swing, tick = handlers.EveryOneMinute, handlers.OnPlayerGetDamage, handlers.OnPlayerUpdate, handlers.OnWeaponSwing, handlers.OnTick
local function out(p) return DanTraits_IsPassedOut(p) end
-- let a blackout run its course: game minutes and real seconds
local function wake(minutes) hours = hours + minutes / 60; ms = ms + 60000; tick() end
local function D(p) return p._md.DanTraits end
local function near(a, b, tol, msg) assert(math.abs(a - b) <= tol, msg .. ": " .. tostring(a) .. " vs " .. tostring(b)) end

-- 1. falls: under 3 nothing; the chance climbs to certain at 15; how bad from 0.25 up
local p = makePlayer(); current = p
nextRoll = 0
damage(p, "FALLDOWN", 2.5); assert(D(p).ccScore == nil and D(p).ccLastImpact == "FALLDOWN 2.5", "a light fall: nothing, but noted")
nextRoll = 0.49; damage(p, "FALLDOWN", 9); near(D(p).ccScore, 0.25 + 0.04 * 6, 1e-9, "fall of 9 (a high drop): 50% chance, roll 0.49 takes; 0.49")
assert(halo[#halo] == "UI_DanTraits_ConcussionModerate" or out(p), "moderate: ears ringing (or a brief blackout)")
if out(p) then wake(5) end
p = makePlayer(); current = p; nextRoll = 0.51
damage(p, "FALLDOWN", 9); assert(D(p).ccScore == nil, "roll 0.51: missed")
damage(p, "FALLDOWN", 1000); assert(D(p) == nil or D(p).ccScore == nil, "a lethal fall is the game's business")

-- 2. mild: a notice, no blackout
p = makePlayer(); current = p; nextRoll = 0.99; halo = {}
DanTraits_KnockHead(p, 1, 0.3)
assert(D(p).ccScore == 0.3 and halo[1] == "UI_DanTraits_ConcussionMild" and not out(p), "mild")

-- 3. severe: knocked out, 5-15 game minutes by how bad (never under 8 real
-- seconds): the fall, sat on the floor, screen black, held; then comes round
p = makePlayer(); current = p; halo = {}
DanTraits_KnockHead(p, 1, 0.85)
assert(out(p) and p._bump == "stagger" and p._vars.BumpFall == true and p._blocked and faded, "out: fallen, blocked, black")
ms = ms + 1000; tick(); assert(not p._sitting, "the fall plays out first")
ms = ms + 1000; tick(); assert(p._sitting, "then sat on the floor")
hours = hours + 9.9 / 60; ms = ms + 60000; tick(); assert(out(p), "0.85: ten game minutes, not yet")
hours = hours + 0.2 / 60; tick()
assert(not out(p) and not p._blocked and faded == false and halo[#halo] == "UI_DanTraits_ConcussionComeTo", "comes round")
DanTraits_PassOut(p, 0.1); hours = hours + 1; ms = ms + 5000; tick(); assert(out(p), "at least 8 real seconds")
ms = ms + 3100; tick(); assert(not out(p), "then round")

-- 3b. a faint ends when something wounds you; a knockout (deep) doesn't
p = makePlayer(); current = p; halo = {}
DanTraits_PassOut(p, 10)
for _ = 1, 10 do tick() end; assert(out(p), "nothing happening: still out")
p._wounds = 1; for _ = 1, 10 do tick() end
assert(not out(p) and halo[#halo] == "UI_DanTraits_JoltedAwake", "bitten: jolted awake")
p = makePlayer(); current = p
DanTraits_PassOut(p, 10, nil, true); p._wounds = 1; for _ = 1, 20 do tick() end
assert(out(p), "knocked out: stays down"); wake(20)

-- 4. a helmet: less likely, less bad
p = makePlayer(); current = p; p._defense = 80
nextRoll = 0.5; DanTraits_KnockHead(p, 1, 0.5)
assert(D(p) == nil or D(p).ccScore == nil, "helmet: 40% chance, roll 0.5 misses")
nextRoll = 0.3; DanTraits_KnockHead(p, 1, 0.5); near(D(p).ccScore, 0.3, 1e-9, "helmet: 0.5 x 0.6")

-- 5. a second knock lands on top; severe by stacking knocks you out
p = makePlayer(); current = p; nextRoll = 0.99
DanTraits_KnockHead(p, 1, 0.3); DanTraits_KnockHead(p, 1, 0.5)
near(D(p).ccScore, 0.5 + 0.5 * 0.3, 1e-9, "stacked: 0.65")
DanTraits_KnockHead(p, 1, 0.3); near(D(p).ccScore, 0.65 + 0.15, 1e-9, "past severe")
assert(out(p), "and out"); wake(20)

-- 6. weapon hits count by what they took off the head
p = makePlayer(); current = p; nextRoll = 0.4
frame(p); p._head._health = 90; damage(p, "WEAPONHIT", 3)
near(D(p).ccScore, 0.25 + 0.025 * 10, 1e-9, "10 off the head: 50% chance, 0.5")
local q = makePlayer(); current = q
frame(q); damage(q, "WEAPONHIT", 3); assert(D(q) == nil or D(q).ccScore == nil, "a hit elsewhere: nothing")

-- 7. symptoms: headache, queasy (moderate), tired, slower endurance
p = makePlayer(); current = p; nextRoll = 0.99
DanTraits_KnockHead(p, 1, 0.3); minute()
near(p._head._pain, 15 + 35 * D(p).ccScore, 1e-9, "headache")
assert(p._st.foodsick == 0 and p._st.fatigue > 0, "mild: not queasy, drowsy")
DanTraits_KnockHead(p, 1, 0.5); minute()
near(p._st.foodsick, 0.3 * D(p).ccScore * 100, 1e-6, "moderate: queasy")
p._st.endurance = 0.5; frame(p); p._st.endurance = 0.6; frame(p)
near(p._st.endurance, 0.5 + 0.1 * (1 - 0.3 * D(p).ccScore), 1e-9, "slower endurance")

-- 8. running when moderate: a dizzy fall
p = makePlayer(); current = p; nextRoll = 0.99
DanTraits_KnockHead(p, 1, 0.6); halo = {}; p._bump = nil
p._run = true; frame(p); nextRoll = 0.05; minute(); p._run = false
assert(p._bump == "stagger" and halo[#halo] == "UI_DanTraits_ConcussionDizzy", "dizzy fall")

-- 9. healing: 0.25 a day at rest, x2 asleep; strain stops it and adds a little
p = makePlayer(); current = p; nextRoll = 0.99
DanTraits_KnockHead(p, 1, 0.3); local s = D(p).ccScore
minute(); near(D(p).ccScore, s - 0.25 / 1440, 1e-9, "resting")
s = D(p).ccScore; p._asleep = true; minute(); p._asleep = false
near(D(p).ccScore, s - 0.5 / 1440, 1e-9, "asleep: twice")
s = D(p).ccScore; swing(p); minute(); near(D(p).ccScore, s + 0.0005, 1e-9, "a fight: worse")
D(p).ccScore = 0.02; halo = {}; minute(); minute()
for _ = 1, 30 do minute() end
assert(D(p).ccScore == nil and halo[#halo] == "+UI_DanTraits_ConcussionClear" or string.find(halo[#halo] or "", "ConcussionClear", 1, true), "cleared, with a notice")

-- 10. light wakes a concussed sleeper more easily
p = makePlayer(); current = p; p._md.DanTraits = { ccScore = 0.5 }
near(DanTraits_RunHooks("sleepWake", 1, p, D(p)), 1.5, 1e-9, "sleep: light wakes x1.5")

-- 11. sandbox switch, commands
SandboxVars = { DanTraits = { ConcussionEnabled = false } }
p = makePlayer(); current = p; nextRoll = 0; damage(p, "FALLDOWN", 14)
assert(D(p) == nil or D(p).ccScore == nil, "off: no concussion")
SandboxVars = nil
p = makePlayer(); current = p; nextRoll = 0.99
assert(DanTraits_ExtraCommands.concussion(p, { "0.3" }) == "concussion 0.3", "set")
assert(DanTraits_ExtraCommands.concussion(p, { "clear" }) == "concussion cleared" and D(p).ccScore == nil, "clear")
assert(string.find(DanTraits_ExtraCommands.faint(p, { "out", "5" }), "out for 5 game minutes: true", 1, true) and out(p), "faint out")

print("test_concussion: all passed")
